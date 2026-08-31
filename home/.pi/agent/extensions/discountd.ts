/**
 * discountd - the discount daemon. Always watching for the next deal.
 *
 * Sources:
 *   or (OpenRouter) - the original source. Reads OpenRouter's frontend models
 *     API (?discount=true) - the same promotional-discount list behind the
 *     "Discounted AI Models" collection.
 *   cf (Cloudflare AI Gateway) - parses Cloudflare's public AI Gateway
 *     changelog RSS for promotional offers ("Get X% off <model> through AI
 *     Gateway", e.g. the 50% off GPT-5.6 Sol offer) and normalizes them into
 *     the same deal table. Listings need no API key - the dashboard itself is
 *     behind auth, but Cloudflare publishes every promo in its changelog.
 *
 * Future provider members (azure, bedrock, ...) slot in behind the same
 * command as additional sources.
 *
 *   /discountd            🔥 Deal of the Day + coding-focused deals (all sources)
 *   /discountd or         OpenRouter deals
 *   /discountd cf         Cloudflare AI Gateway deals
 *   /discountd all        All discounted models, sorted by discount
 *   /discountd free       Free coding-capable models ($0 tokens)
 *   /discountd cheap      Cheapest paid coding models
 *   /discountd pick       Pick a model from the deals list and activate it
 *   /discountd pick <id>  Activate a specific deal model by slug (no picker)
 *   /discountd refresh    Force-refresh the cached data
 *
 * Data sources:
 *   - OpenRouter: https://openrouter.ai/api/frontend/v1/models/find?discount=true
 *   - Cloudflare: https://developers.cloudflare.com/changelog/rss/ai-gateway.xml
 *     (changelog entries carrying "X% off" plus a promotional/standard pricing table)
 *
 * Coding relevance is classified from OpenRouter's "programming" usage
 * analytics (per-model category volume/rank) plus slug/name heuristics.
 * Cloudflare models fall back to the heuristics.
 *
 * `pick` activates a deal model in the current pi session:
 *   - OpenRouter deals: registers the model on the openrouter provider on the
 *     fly (preserving any existing OpenRouter models) and switches the session
 *     model to the OpenRouter deal endpoint. Requires OPENROUTER_API_KEY (or
 *     /login openrouter).
 *   - Cloudflare deals: registers the model on the cloudflare-ai-gateway
 *     provider through the unified AI REST API
 *     (api.cloudflare.com/client/v4/accounts/<id>/ai/v1), where AI Gateway
 *     promotional pricing applies automatically. Requires CLOUDFLARE_API_TOKEN
 *     and CLOUDFLARE_ACCOUNT_ID (or CLOUDFLARE_API_KEY / /login cloudflare-ai-gateway).
 */

import type {
  ExtensionAPI,
  ExtensionCommandContext,
  ProviderModelConfig,
} from "@earendil-works/pi-coding-agent";
import { homedir } from "node:os";
import { join } from "node:path";
import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";

const MODELS_FIND_URL = "https://openrouter.ai/api/frontend/v1/models/find";
const CF_CHANGELOG_RSS =
  "https://developers.cloudflare.com/changelog/rss/ai-gateway.xml";
const OR_URL_PREFIX = "https://openrouter.ai/";
const MESSAGE_TYPE = "discountd";
const UA = "pi-discountd/0.2 (pi extension; contact: user)";

const CACHE_DIR_ENV = "PI_DISCOUNTD_CACHE_DIR";
const DEALS_TTL_MS = 6 * 60 * 60 * 1000; // discounted list is small + volatile
const CATALOG_TTL_MS = 24 * 60 * 60 * 1000; // full catalog is ~5MB, static-ish
const FETCH_TIMEOUT_MS = 20_000;

// --- Types ---------------------------------------------------------------

type DealSource = "openrouter" | "cloudflare";

/** One discounted offer, normalized across marketplaces. Prices are $/token. */
/** One discounted offer, normalized across marketplaces. Prices are $/token. */
export interface Deal {
  source: DealSource;
  modelId: string; // e.g. "openai/gpt-5.6-sol" (or the OpenRouter slug)
  name: string;
  provider: string; // display name, e.g. "DeepInfra", "Cloudflare AI Gateway"
  discount: number; // 0..1
  prompt?: number; // promotional input price
  completion?: number; // promotional output price
  cacheRead?: number;
  promptStd?: number; // standard (non-promotional) prices, when known
  completionStd?: number;
  contextWindow?: number;
  maxTokens?: number;
  url: string;
  coding: boolean;
  endsAt?: string; // human-readable, e.g. "September 18, 2026"
}

interface Pricing {
  prompt?: string;
  completion?: string;
  input_cache_read?: string;
  discount?: number;
}

interface Endpoint {
  provider_display_name?: string;
  provider_slug?: string;
  variant?: string;
  is_free?: boolean;
  max_completion_tokens?: number;
  pricing?: Pricing;
}

interface ModelEntry {
  slug: string;
  permaslug?: string;
  name?: string;
  description?: string;
  context_length?: number;
  endpoint?: Endpoint;
}

interface CategoryStat {
  date?: string;
  category?: string;
  count?: number;
  volume?: number;
  rank?: number;
}

interface CatalogPayload {
  models?: ModelEntry[];
  categories?: Record<string, CategoryStat[]>;
}

interface CacheEntry<T> {
  fetchedAt: number;
  data: T;
}

interface RssItem {
  title: string;
  link: string;
  pubDate: string;
  description: string;
}

// --- Coding classification ------------------------------------------------

const CODING_RE =
  /(coder|codex|codestral|devstral|kat-coder|grok-build|swe-|-swe|ox-alpha|sol-pro|\bsol\b|code-latest|\bcode\b|nemotron|laguna|coding)/i;

function codingSignal(
  slug: string,
  name: string,
  perm: string | undefined,
  categories: Record<string, CategoryStat[]>,
): { coding: boolean; volume: number; rank: number } {
  const hay = `${slug} ${name}`.toLowerCase();
  const heuristic = CODING_RE.test(hay);
  let volume = 0;
  let rank = 0;
  if (perm) {
    for (const e of categories[perm] ?? []) {
      if (e.category === "programming") {
        volume = e.volume ?? 0;
        rank = e.rank ?? 0;
      }
    }
  }
  // Analytics (top-usage programming signal) trumps heuristics both ways:
  // a clearly general model with heavy coding usage counts as coding, and a
  // model with zero usage analytics falls back to the name heuristic.
  const coding = heuristic || volume > 1 || (rank > 0 && rank <= 60);
  return { coding, volume, rank };
}

function classifyCoding(
  m: ModelEntry,
  categories: Record<string, CategoryStat[]>,
) {
  return codingSignal(
    m.slug,
    m.name ?? m.slug,
    m.permaslug ?? m.slug,
    categories,
  );
}

// --- Cache ----------------------------------------------------------------

function cacheDir(): string {
  return (
    process.env[CACHE_DIR_ENV] || join(homedir(), ".cache", "pi-discountd")
  );
}

function loadCache<T>(name: string): CacheEntry<T> | null {
  try {
    const raw = readFileSync(join(cacheDir(), name), "utf8");
    return JSON.parse(raw) as CacheEntry<T>;
  } catch {
    return null;
  }
}

function saveCache<T>(name: string, data: T): void {
  try {
    mkdirSync(cacheDir(), { recursive: true });
    // Write to a temp file and rename so a crash can't corrupt the cache.
    const file = join(cacheDir(), name);
    const tmp = `${file}.tmp`;
    writeFileSync(tmp, JSON.stringify({ fetchedAt: Date.now(), data }), "utf8");
    renameSync(tmp, file);
  } catch {
    // cache is best-effort
  }
}

/**
 * Load from cache (when fresh), otherwise fetch + save. Falls back to the
 * stale cache when the fetch fails so the command still works offline.
 */
async function withCache<T>(
  name: string,
  ttlMs: number,
  force: boolean,
  fetcher: () => Promise<T>,
): Promise<{ data: T; stale: boolean }> {
  const cached = loadCache<T>(name);
  if (!force && cached && Date.now() - cached.fetchedAt < ttlMs) {
    return { data: cached.data, stale: false };
  }
  try {
    const data = await fetcher();
    saveCache(name, data);
    return { data, stale: false };
  } catch (err) {
    if (cached) return { data: cached.data, stale: true };
    throw err;
  }
}

async function fetchText(url: string): Promise<string> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  try {
    const res = await fetch(url, {
      headers: { "User-Agent": UA },
      signal: controller.signal,
    });
    if (!res.ok) throw new Error(`HTTP ${res.status} from ${url}`);
    return await res.text();
  } finally {
    clearTimeout(timer);
  }
}

async function fetchJson<T>(url: string): Promise<T> {
  const text = await fetchText(url);
  try {
    return JSON.parse(text) as T;
  } catch (err) {
    // Rethrow so callers can fall back to their stale cache.
    throw new Error(`Invalid JSON from ${url}: ${(err as Error).message}`);
  }
}

// --- OpenRouter source ------------------------------------------------------

/** Returns the discounted OpenRouter models as normalized deals, cached. */
async function fetchOpenRouterDeals(
  force: boolean,
): Promise<{ deals: Deal[]; stale: boolean }> {
  const { data: payload, stale } = await withCache<CatalogPayload>(
    "deals.json",
    DEALS_TTL_MS,
    force,
    async () => {
      const r = await fetchJson<{ data: CatalogPayload }>(
        `${MODELS_FIND_URL}?discount=true&limit=2000`,
      );
      return r.data;
    },
  );
  const categories = payload.categories ?? {};
  const deals: Deal[] = [];
  for (const m of payload.models ?? []) {
    const ep = m.endpoint;
    const disc = ep?.pricing?.discount ?? 0;
    if (disc <= 0) continue;
    const { coding } = classifyCoding(m, categories);
    const p = ep?.pricing;
    deals.push({
      source: "openrouter",
      modelId: m.slug,
      name: m.name ?? m.slug,
      provider: `${ep?.provider_display_name ?? "?"}${
        ep?.variant && ep.variant !== "standard" ? " (" + ep.variant + ")" : ""
      }`,
      discount: disc,
      prompt: p?.prompt ? parseFloat(p.prompt) : undefined,
      completion: p?.completion ? parseFloat(p.completion) : undefined,
      cacheRead: p?.input_cache_read
        ? parseFloat(p.input_cache_read)
        : undefined,
      contextWindow: m.context_length,
      maxTokens: ep?.max_completion_tokens,
      url: `${OR_URL_PREFIX}${m.slug}`,
      coding,
    });
  }
  return { deals, stale };
}

/** Returns the full OpenRouter model catalog, cached. Used for free + cheap lists. */
async function getCatalog(
  force: boolean,
): Promise<{ payload: CatalogPayload; stale: boolean }> {
  const { data: payload, stale } = await withCache<CatalogPayload>(
    "catalog.json",
    CATALOG_TTL_MS,
    force,
    async () => {
      const r = await fetchJson<{ data: CatalogPayload }>(
        `${MODELS_FIND_URL}?limit=2000`,
      );
      return r.data;
    },
  );
  return { payload, stale };
}

// --- Cloudflare source -------------------------------------------------------

const CF_MODEL_ID_RE =
  /^(?:openai|anthropic|google|google-ai-studio|meta|mistral|deepseek|cohere|perplexity|x-ai|amazon|microsoft|moonshot|moonshotai|zai|qwen|minimax|groq|fireworks|together|huggingface|elevenlabs|cartesia|cerebras|workers-ai|@cf)\/[a-z0-9][a-z0-9._-]*$/i;

function decodeEntities(s: string): string {
  return s
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, "&");
}

function stripTags(s: string): string {
  return s.replace(/<[^>]*>/g, "");
}

function parseRss(xml: string): RssItem[] {
  const items: RssItem[] = [];
  const fieldRe = /<(title|link|pubDate|description)>([\s\S]*?)<\/\1>/g;
  for (const m of xml.matchAll(/<item>([\s\S]*?)<\/item>/g)) {
    const block = m[1];
    const fields: Record<string, string> = {};
    for (const f of block.matchAll(fieldRe)) fields[f[1]] = f[2];
    items.push({
      title: decodeEntities(fields.title ?? ""),
      link: fields.link ?? "",
      pubDate: fields.pubDate ?? "",
      description: fields.description ?? "",
    });
  }
  return items;
}

function parsePriceCell(s: string | undefined): number | undefined {
  if (!s) return undefined;
  const m = s.match(/\$([\d.]+)\s*per\s*(\d+(?:\.\d+)?)\s*(K|M)\s*tokens?/i);
  if (!m) return undefined;
  const amount = parseFloat(m[1]);
  const count = parseFloat(m[2]);
  const mult = m[3].toUpperCase() === "K" ? 1e3 : 1e6;
  return count > 0 ? amount / (count * mult) : undefined;
}

interface PromoPricing {
  input?: number;
  output?: number;
  cacheRead?: number;
  inputStd?: number;
  outputStd?: number;
  cacheReadStd?: number;
}

/** Parse a markdown-style pricing table with promotional + standard columns. */
function parsePromoTable(descHtml: string): PromoPricing | null {
  const table = descHtml.match(/<table>([\s\S]*?)<\/table>/i);
  if (!table) return null;
  const rows = [...table[1].matchAll(/<tr[^>]*>([\s\S]*?)<\/tr>/gi)].map((r) =>
    [...r[1].matchAll(/<t[dh][^>]*>([\s\S]*?)<\/t[dh]>/gi)].map((c) =>
      stripTags(decodeEntities(c[1])).trim(),
    ),
  );
  if (rows.length < 2) return null;
  const header = rows[0].map((h) => h.toLowerCase());
  const promoIdx = header.findIndex((h) => h.includes("promo"));
  const stdIdx = header.findIndex((h) => h.includes("standard"));
  if (promoIdx < 0) return null;

  const out: PromoPricing = {};
  for (const row of rows.slice(1)) {
    const label = (row[0] ?? "").toLowerCase();
    const promo = row[promoIdx];
    const std = stdIdx >= 0 ? row[stdIdx] : undefined;
    if (label.includes("input")) {
      out.input = parsePriceCell(promo);
      out.inputStd = parsePriceCell(std);
    } else if (label.includes("output")) {
      out.output = parsePriceCell(promo);
      out.outputStd = parsePriceCell(std);
    } else if (label.includes("cache read") || label.includes("cached input")) {
      out.cacheRead = parsePriceCell(promo);
      out.cacheReadStd = parsePriceCell(std);
    }
  }
  return out;
}

/** Pull the model id out of `<code>provider/model</code>` snippets. */
function extractModelId(descHtml: string): string | undefined {
  const codes = [...descHtml.matchAll(/<code>([\s\S]*?)<\/code>/gi)].map((c) =>
    decodeEntities(c[1]).trim(),
  );
  return codes.find((code) => CF_MODEL_ID_RE.test(code));
}

function prettifyModelId(modelId: string): string {
  const last = modelId.split("/").pop() ?? modelId;
  return last.replace(/[-_]/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

function fmtEnds(endsAt: string): string {
  const m = endsAt.match(/^(\w+)\s+(\d{1,2}),\s*(\d{4})$/);
  if (!m) return endsAt;
  const full = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];
  const short = [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ];
  const idx = full.indexOf(m[1]);
  return `${idx >= 0 ? short[idx] : m[1]} ${m[2]}, ${m[3]}`;
}

function isExpired(endsAt: string | undefined): boolean {
  if (!endsAt) return false;
  const end = new Date(endsAt);
  if (Number.isNaN(end.getTime())) return false;
  // The listed date is inclusive (runs "through" that day).
  return end.getTime() + 24 * 60 * 60 * 1000 < Date.now();
}

/** Convert one AI Gateway changelog item into a deal, or null if not a promo. */
function parseCloudflareDeal(item: RssItem): Deal | null {
  const title = decodeEntities(item.title);
  // RSS descriptions are HTML-escaped; decode first, then treat as HTML for
  // table/code extraction.
  const descHtml = decodeEntities(item.description);
  const descText = stripTags(descHtml);

  // Must be an explicit "X% off" promotion.
  const discMatch = `${title} ${descText}`.match(/(\d+(?:\.\d+)?)\s*%\s*off/i);
  if (!discMatch) return null;
  const discount = parseFloat(discMatch[1]) / 100;
  if (discount <= 0 || discount > 1) return null;

  const modelId = extractModelId(descHtml);
  if (!modelId) return null;

  const pricing = parsePromoTable(descHtml);
  if (!pricing || pricing.input === undefined || pricing.output === undefined) {
    return null;
  }

  const endsMatch = descText.match(
    /(?:runs through|valid until|available through|until)\s+([A-Z][a-z]+ \d{1,2}, \d{4})/i,
  );
  const endsAt = endsMatch ? endsMatch[1] : undefined;
  if (isExpired(endsAt)) return null;

  const nameMatch = title.match(/off\s+(.+?)(?:\s+through|\s+via|\s*$)/i);
  const name = nameMatch ? nameMatch[1].trim() : prettifyModelId(modelId);
  const { coding } = codingSignal(modelId, name, undefined, {});

  return {
    source: "cloudflare",
    modelId,
    name,
    provider: "Cloudflare AI Gateway",
    discount,
    prompt: pricing.input,
    completion: pricing.output,
    cacheRead: pricing.cacheRead,
    promptStd: pricing.inputStd,
    completionStd: pricing.outputStd,
    url: item.link,
    coding,
    endsAt,
  };
}

/** Parse the AI Gateway changelog RSS into live deals (newest entry per model). */
export function parseCloudflarePromos(xml: string): Deal[] {
  const byModel = new Map<string, Deal>();
  for (const item of parseRss(xml)) {
    const deal = parseCloudflareDeal(item);
    if (!deal) continue;
    // RSS is newest-first; keep the newest entry per model.
    if (!byModel.has(deal.modelId)) byModel.set(deal.modelId, deal);
  }
  return [...byModel.values()];
}

/** Returns the Cloudflare AI Gateway promotional deals, cached. */
async function fetchCloudflareDeals(
  force: boolean,
): Promise<{ deals: Deal[]; stale: boolean }> {
  const { data: xml, stale } = await withCache<string>(
    "cloudflare.xml",
    DEALS_TTL_MS,
    force,
    () => fetchText(CF_CHANGELOG_RSS),
  );
  return { deals: parseCloudflarePromos(xml), stale };
}

async function fetchSourceDeals(
  source: DealSource,
  force: boolean,
): Promise<{ deals: Deal[]; stale: boolean }> {
  return source === "cloudflare"
    ? fetchCloudflareDeals(force)
    : fetchOpenRouterDeals(force);
}

async function fetchAllSources(
  sources: DealSource[],
  force: boolean,
): Promise<{ deals: Deal[]; stale: boolean; failed: number }> {
  const results = await Promise.allSettled(
    sources.map((s) => fetchSourceDeals(s, force)),
  );
  const fulfilled = results.filter(
    (r): r is PromiseFulfilledResult<{ deals: Deal[]; stale: boolean }> =>
      r.status === "fulfilled",
  );
  return {
    deals: fulfilled.flatMap((r) => r.value.deals),
    stale:
      fulfilled.some((r) => r.value.stale) ||
      results.some((r) => r.status === "rejected"),
    failed: results.length - fulfilled.length,
  };
}

// --- Formatting -----------------------------------------------------------

function perM(num: number | undefined): string {
  if (num === undefined || Number.isNaN(num)) return "?";
  const m = num * 1e6; // API prices are per-token USD
  if (m === 0) return "$0";
  if (m < 0.01) return `$${(m * 1000).toFixed(2)}/K`;
  if (m < 0.1) return `$${m.toFixed(3)}/M`;
  if (m < 1) return `$${m.toFixed(2)}/M`;
  // Whole dollars: "$15/M"; otherwise keep 2 decimals ("$2.50/M").
  return Number.isInteger(m) ? `$${m}/M` : `$${m.toFixed(2)}/M`;
}

export function renderDeals(deals: Deal[], codingOnly: boolean): string {
  const byModel = new Map<string, Deal>();
  for (const d of deals) {
    if (codingOnly && !d.coding) continue;
    const key = `${d.source}:${d.modelId}`;
    const existing = byModel.get(key);
    // Prefer the biggest discount; tie-break by cheapest input price.
    if (
      !existing ||
      d.discount > existing.discount ||
      (d.discount === existing.discount &&
        (d.prompt ?? Infinity) < (existing.prompt ?? Infinity))
    ) {
      byModel.set(key, d);
    }
  }

  const rows = [...byModel.values()].sort(
    (a, b) =>
      b.discount - a.discount ||
      (a.prompt ?? Infinity) - (b.prompt ?? Infinity),
  );
  const spotlight = rows[0]
    ? `🔥 **Deal of the Day** - ${Math.round(rows[0].discount * 100)}% off **${rows[0].modelId}** (${rows[0].provider}${rows[0].endsAt ? ` · until ${fmtEnds(rows[0].endsAt)}` : ""}) · ${perM(rows[0].prompt)} in / ${perM(rows[0].completion)} out\n\n`
    : "";
  const header =
    "| type | off | model | provider | in | out |\n" +
    "|------|-----|-------|----------|-----|-----|\n";
  const lines = rows.map((r) => {
    const provider = r.endsAt
      ? `${r.provider} · until ${fmtEnds(r.endsAt)}`
      : r.provider;
    return `| ${r.coding ? "code" : "gen"} | ${Math.round(r.discount * 100)}% | ${r.modelId} | ${provider} | ${perM(r.prompt)} | ${perM(r.completion)} |`;
  });
  return spotlight + header + lines.join("\n");
}

function renderFree(payload: CatalogPayload): string {
  const categories = payload.categories ?? {};
  const rows: Array<{ coding: boolean; vol: number; line: string }> = [];

  for (const m of payload.models ?? []) {
    if (!m.endpoint?.is_free) continue;
    const { coding, volume } = classifyCoding(m, categories);
    rows.push({
      coding,
      vol: volume,
      line: `| ${coding ? "code" : "gen"} | ${m.slug} | ${m.name ?? ""} |`,
    });
  }

  // Free endpoints all cost $0; show coding-capable models first, ranked by
  // observed programming usage, then the rest alphabetically.
  rows.sort((a, b) =>
    b.coding === a.coding
      ? b.vol - a.vol || a.line.localeCompare(b.line)
      : Number(b.coding) - Number(a.coding),
  );
  const header =
    "| type | model (free :free variant) | name |\n|------|---------------------------|------|\n";
  return header + rows.map((r) => r.line).join("\n");
}

function renderCheap(payload: CatalogPayload): string {
  const categories = payload.categories ?? {};
  const rows: Array<{ in: number; line: string }> = [];

  for (const m of payload.models ?? []) {
    const ep = m.endpoint;
    if (!ep || ep.is_free) continue;
    const { coding } = classifyCoding(m, categories);
    if (!coding) continue;
    const input = ep.pricing?.prompt
      ? parseFloat(ep.pricing.prompt)
      : undefined;
    if (input === undefined) continue;
    rows.push({
      in: input,
      line: `| ${m.slug} | ${ep.provider_display_name ?? "?"} | ${perM(ep.pricing?.prompt ? parseFloat(ep.pricing.prompt) : undefined)} | ${perM(ep.pricing?.completion ? parseFloat(ep.pricing.completion) : undefined)} |`,
    });
  }

  rows.sort((a, b) => a.in - b.in);
  const header =
    "| model | provider | in | out |\n|-------|----------|-----|-----|\n";
  return (
    header +
    rows
      .slice(0, 25)
      .map((r) => r.line)
      .join("\n")
  );
}

// --- Model activation -------------------------------------------------------

function readProviderModels(
  ctx: ExtensionCommandContext,
  provider: string,
): ProviderModelConfig[] {
  try {
    const out: ProviderModelConfig[] = [];
    for (const mod of ctx.modelRegistry.getAll()) {
      if (mod.provider !== provider) continue;
      out.push({
        id: mod.id,
        name: mod.name,
        api: mod.api,
        baseUrl: mod.baseUrl,
        reasoning: mod.reasoning,
        thinkingLevelMap: mod.thinkingLevelMap,
        input: mod.input,
        cost: mod.cost,
        contextWindow: mod.contextWindow,
        maxTokens: mod.maxTokens,
        headers: mod.headers,
        compat: mod.compat,
      });
    }
    return out;
  } catch {
    // registry reads may fail in minimal contexts
    return [];
  }
}

/** Check if OpenRouter auth is available (env var or stored credentials). */
async function checkOpenRouterAuth(
  ctx: ExtensionCommandContext,
): Promise<boolean> {
  if (process.env.OPENROUTER_API_KEY) return true;
  try {
    const auth = await ctx.modelRegistry.getProviderAuth("openrouter");
    return Boolean(auth);
  } catch {
    return false;
  }
}

/**
 * Check if Cloudflare auth is available (env vars or stored credentials).
 * Returns the resolved API key too, so activation can attach the
 * `Authorization: Bearer` header the unified AI REST API expects (pi's native
 * cloudflare-ai-gateway auth resolves to a `cf-aig-authorization` header
 * instead, which is for the legacy gateway.ai.cloudflare.com endpoints).
 */
async function checkCloudflareAuth(ctx: ExtensionCommandContext): Promise<{
  ok: boolean;
  accountId: string | undefined;
  apiKey: string | undefined;
}> {
  const envAccount = process.env.CLOUDFLARE_ACCOUNT_ID?.trim();
  const envToken =
    process.env.CLOUDFLARE_API_TOKEN?.trim() ||
    process.env.CLOUDFLARE_API_KEY?.trim();
  if (envAccount && envToken)
    return { ok: true, accountId: envAccount, apiKey: envToken };
  try {
    const auth: any = await ctx.modelRegistry.getProviderAuth(
      "cloudflare-ai-gateway",
    );
    const accountId = auth?.env?.CLOUDFLARE_ACCOUNT_ID ?? envAccount;
    const headerKey = auth?.auth?.headers?.["cf-aig-authorization"];
    const storedKey =
      auth?.auth?.apiKey ??
      (typeof headerKey === "string"
        ? headerKey.replace(/^Bearer\s+/i, "").trim()
        : undefined);
    if (accountId && (storedKey || envToken)) {
      return { ok: true, accountId, apiKey: storedKey ?? envToken };
    }
  } catch {
    // no stored credentials
  }
  return {
    ok: Boolean(envAccount && envToken),
    accountId: envAccount,
    apiKey: envToken,
  };
}

/** Register an OpenRouter deal model on the fly and activate it. */
async function activateViaOpenRouter(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  deal: Deal,
): Promise<boolean> {
  // Preserve any currently registered OpenRouter models in the registry.
  const existingModels = readProviderModels(ctx, "openrouter");
  const modelsMap = new Map<string, ProviderModelConfig>();
  for (const mod of existingModels) modelsMap.set(mod.id, mod);
  const existing = modelsMap.get(deal.modelId);

  modelsMap.set(deal.modelId, {
    id: deal.modelId,
    name: deal.name,
    reasoning: true,
    input: existing?.input ?? (["text"] as const),
    cost: {
      input: (deal.prompt ?? 0) * 1e6,
      output: (deal.completion ?? 0) * 1e6,
      cacheRead: (deal.cacheRead ?? 0) * 1e6,
      cacheWrite: existing?.cost?.cacheWrite ?? 0,
    },
    contextWindow: deal.contextWindow ?? existing?.contextWindow ?? 128000,
    maxTokens: deal.maxTokens ?? existing?.maxTokens ?? 8192,
    thinkingLevelMap: existing?.thinkingLevelMap,
    headers: existing?.headers,
    compat: {
      thinkingFormat: "openrouter",
    },
  });

  pi.registerProvider("openrouter", {
    name: "OpenRouter",
    baseUrl: "https://openrouter.ai/api/v1",
    apiKey: "$OPENROUTER_API_KEY",
    api: "openai-completions",
    models: Array.from(modelsMap.values()),
  });

  const model = ctx.modelRegistry.find("openrouter", deal.modelId);
  if (!model) return false;
  return pi.setModel(model);
}

/**
 * Register a Cloudflare AI Gateway deal model on the fly and activate it.
 * Routes through the unified AI REST API (ai/v1) where promotional pricing
 * applies automatically, using the `openai/gpt-5.6-sol`-style model id.
 */
async function activateViaCloudflare(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  deal: Deal,
): Promise<boolean> {
  const auth = await checkCloudflareAuth(ctx);
  if (!auth.ok || !auth.accountId) return false;

  const baseUrl = `https://api.cloudflare.com/client/v4/accounts/${auth.accountId}/ai/v1`;
  // The unified AI REST API expects `Authorization: Bearer <token>`, so pin
  // the resolved key on the model (pi's native cloudflare-ai-gateway auth
  // would otherwise send `cf-aig-authorization` for the legacy endpoints).
  const bearerHeaders: Record<string, string> = auth.apiKey
    ? { Authorization: `Bearer ${auth.apiKey}` }
    : {};
  // Preserve any currently registered cloudflare-ai-gateway models.
  const existingModels = readProviderModels(ctx, "cloudflare-ai-gateway");
  const modelsMap = new Map<string, ProviderModelConfig>();
  for (const mod of existingModels) modelsMap.set(mod.id, mod);
  // Prefer an existing registration of the same model (id may differ by
  // namespace, e.g. "gpt-5.6-sol" vs "openai/gpt-5.6-sol").
  const existing =
    modelsMap.get(deal.modelId) ??
    [...modelsMap.values()].find(
      (m) =>
        m.id === deal.modelId.replace(/^openai\//, "") ||
        deal.modelId === `openai/${m.id}`,
    );

  modelsMap.set(deal.modelId, {
    id: deal.modelId,
    name: deal.name,
    reasoning: true,
    input: existing?.input ?? (["text"] as const),
    cost: {
      input: (deal.prompt ?? 0) * 1e6,
      output: (deal.completion ?? 0) * 1e6,
      cacheRead: (deal.cacheRead ?? 0) * 1e6,
      cacheWrite: existing?.cost?.cacheWrite ?? 0,
    },
    contextWindow: existing?.contextWindow ?? 200000,
    maxTokens: existing?.maxTokens ?? 128000,
    api: "openai-responses",
    baseUrl,
    compat: existing?.compat ?? { supportsStrictMode: true },
    thinkingLevelMap: existing?.thinkingLevelMap,
    headers: { ...existing?.headers, ...bearerHeaders },
  });

  pi.registerProvider("cloudflare-ai-gateway", {
    name: "Cloudflare AI Gateway",
    baseUrl,
    apiKey: "$CLOUDFLARE_API_TOKEN",
    api: "openai-responses",
    models: Array.from(modelsMap.values()),
  });

  const model = ctx.modelRegistry.find("cloudflare-ai-gateway", deal.modelId);
  if (!model) return false;
  return pi.setModel(model);
}

/** Present the deals list as a picker and activate the chosen model. */
async function pickDealModel(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  deals: Deal[],
  requested: string | undefined,
): Promise<void> {
  const orAuth = await checkOpenRouterAuth(ctx);
  const cfAuth = await checkCloudflareAuth(ctx);
  const currentModel = ctx.model;

  const providerOf = (s: DealSource): string =>
    s === "cloudflare" ? "cloudflare-ai-gateway" : "openrouter";

  const mark = (d: Deal): string => {
    const isCurrent =
      currentModel?.provider === providerOf(d.source) &&
      currentModel?.id === d.modelId;
    if (isCurrent) return "CURRENT";
    const ready = d.source === "cloudflare" ? cfAuth.ok : orAuth;
    if (ready) return "READY";
    return d.source === "cloudflare"
      ? "needs CF token + account"
      : "needs OpenRouter key";
  };

  const describe = (d: Deal): string => {
    const disc = Math.round(d.discount * 100);
    const src = d.source === "cloudflare" ? "cf" : "or";
    const until = d.endsAt ? ` · until ${fmtEnds(d.endsAt)}` : "";
    return `[${src}] ${d.coding ? "[code]" : "[gen]"} ${disc}% off ${d.modelId} (${d.provider}) ${perM(d.prompt)}/${perM(d.completion)}${until} - ${mark(d)}`;
  };

  const pick = async (d: Deal): Promise<void> => {
    if (d.source === "cloudflare") {
      if (!cfAuth.ok) {
        ctx.ui.notify(
          "Cloudflare isn't configured. Run /login cloudflare-ai-gateway (or set CLOUDFLARE_API_TOKEN + CLOUDFLARE_ACCOUNT_ID), then retry.",
          "error",
        );
        return;
      }
      if (await activateViaCloudflare(pi, ctx, d)) {
        ctx.ui.notify(
          `Switched to Cloudflare AI Gateway: ${d.modelId}`,
          "info",
        );
        return;
      }
      ctx.ui.notify(
        "Cloudflare activation failed. Check your /login cloudflare-ai-gateway credentials (API key must have AI Gateway + Workers AI permissions).",
        "error",
      );
      return;
    }
    if (await activateViaOpenRouter(pi, ctx, d)) {
      ctx.ui.notify(`Switched to OpenRouter: ${d.modelId}`, "info");
      return;
    }
    ctx.ui.notify(
      "OpenRouter isn't configured. Set OPENROUTER_API_KEY (or run /login openrouter), then retry.",
      "error",
    );
  };

  if (requested) {
    // Optional source prefix disambiguates models that exist on several
    // marketplaces: "/discountd pick cf openai/gpt-5.6-sol".
    let q = requested.toLowerCase();
    let scoped = deals;
    const scopeMatch = /^(cf|or|cloudflare|openrouter)\s+(.+)$/.exec(q);
    if (scopeMatch) {
      scoped = deals.filter((d) =>
        scopeMatch[1] === "cf" || scopeMatch[1] === "cloudflare"
          ? d.source === "cloudflare"
          : d.source === "openrouter",
      );
      q = scopeMatch[2];
    }
    // Exact model/name match wins over substring (so "gpt-5.6-sol" never
    // silently matches "gpt-5.6-sol-pro").
    const exact = scoped.find(
      (d) => d.modelId.toLowerCase() === q || d.name.toLowerCase() === q,
    );
    const match =
      exact ??
      scoped.find(
        (d) =>
          d.modelId.toLowerCase().includes(q) ||
          d.name.toLowerCase().includes(q),
      );
    if (!match) {
      ctx.ui.notify(
        `No deal model matches "${requested}". Try /discountd pick with no args.`,
        "warning",
      );
      return;
    }
    await pick(match);
    return;
  }

  if (deals.length === 0) {
    ctx.ui.notify("No discounted models to pick from.", "warning");
    return;
  }

  const items = deals.map(describe);
  const selected = await ctx.ui.select("Pick a deal model to activate", items);
  if (!selected) return;
  const idx = items.indexOf(selected);
  if (idx >= 0) await pick(deals[idx]);
}

// --- Extension ------------------------------------------------------------

const SOURCE_LABEL = {
  openrouter: "openrouter.ai",
  cloudflare: "developers.cloudflare.com",
} satisfies Record<DealSource, string>;

export default function discountdExtension(pi: ExtensionAPI) {
  // Keep deal output visible in the TUI but out of the LLM's context.
  pi.on("context", (event) => {
    const filtered = event.messages.filter(
      (m) => !(m.role === "custom" && m.customType === MESSAGE_TYPE),
    );
    if (filtered.length !== event.messages.length)
      return { messages: filtered };
  });

  pi.registerCommand("discountd", {
    description:
      "The discount daemon: hot-swap discounted models into your session",
    getArgumentCompletions: (prefix) => {
      const opts = [
        "or",
        "cf",
        "cloudflare",
        "coding",
        "all",
        "free",
        "cheap",
        "pick",
        "refresh",
      ];
      const filtered = opts.filter((o) =>
        o.startsWith((prefix ?? "").toLowerCase()),
      );
      return filtered.length > 0
        ? filtered.map((value) => ({ value, label: value }))
        : null;
    },
    handler: async (args, ctx) => {
      const tokens = (args ?? "")
        .trim()
        .toLowerCase()
        .split(/\s+/)
        .filter(Boolean);
      const cmd = tokens[0] || "coding";
      const rest = tokens.slice(1).join(" ");
      const force = cmd === "refresh";
      const view = force ? "coding" : cmd;
      const codingOnly = view !== "all" && view !== "free" && view !== "cheap";
      const sources: DealSource[] = (() => {
        if (view === "or") return ["openrouter"];
        if (view === "cf" || view === "cloudflare") return ["cloudflare"];
        return ["openrouter", "cloudflare"];
      })();
      const dataLabel =
        view === "free" || view === "cheap"
          ? SOURCE_LABEL.openrouter
          : sources.map((s) => SOURCE_LABEL[s]).join(" + ");

      const emit = (title: string, body: string, stale: boolean) => {
        const stamp = stale ? " (stale cache - refresh failed)" : "";
        pi.sendMessage({
          customType: MESSAGE_TYPE,
          content: `## /discountd ${stamp}\n${body}\n\n_Data: ${dataLabel} - run \`/discountd refresh\` to update._`,
          display: true,
        });
        if (force) ctx.ui.notify(title, "info");
      };

      try {
        if (view === "free") {
          ctx.ui.notify("Fetching free models...", "info");
          const { payload, stale } = await getCatalog(force);
          const body = renderFree(payload);
          emit("Free coding models", body, stale);
          return;
        }
        if (view === "cheap") {
          ctx.ui.notify("Fetching cheapest coding models...", "info");
          const { payload, stale } = await getCatalog(force);
          const body = renderCheap(payload);
          emit("Cheapest coding models", body, stale);
          return;
        }
        if (view === "pick") {
          ctx.ui.notify("Fetching deals...", "info");
          const { deals } = await fetchAllSources(sources, force);
          await pickDealModel(pi, ctx, deals, rest || undefined);
          return;
        }
        // deals views (default: all sources)
        let fetching = "deals";
        if (sources.length === 1) {
          fetching = sources[0] === "cloudflare" ? "Cloudflare" : "OpenRouter";
        }
        ctx.ui.notify(`Fetching ${fetching}...`, "info");
        const { deals, stale, failed } = await fetchAllSources(sources, force);
        if (deals.length === 0 && failed === sources.length) {
          throw new Error("all deal sources failed");
        }
        const body = renderDeals(deals, codingOnly);
        emit(codingOnly ? "Coding deals" : "All deals", body, stale);
      } catch (err) {
        ctx.ui.notify(`discountd failed: ${(err as Error).message}`, "error");
      }
    },
  });
}
