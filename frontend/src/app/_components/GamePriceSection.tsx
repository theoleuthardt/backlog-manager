import { ExternalAnchor } from "components/ExternalAnchor";
import { useState } from "react";
import { ExternalLink, Flame, Loader2, Search, Tag, XIcon } from "lucide-react";
import { useGamePrice, useKeyShopPrices } from "~/hooks/useGameSearch";
import { Button } from "shadcn_components/ui/button";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogTitle,
  DialogTrigger,
} from "shadcn_components/ui/dialog";

interface GamePriceSectionProps {
  steamAppId?: number;
  title: string;
}

const KEY_SHOP_ICONS: Record<string, string> = {
  RoyalCDKeys: "/royalcdkeys-icon.png",
  PremiumCDKeys: "/premiumcdkeys-icon.png",
};

const CURRENCY_SYMBOLS: Record<string, string> = {
  USD: "$",
  EUR: "€",
};

const EUR_PER_UNIT: Record<string, number> = {
  USD: 0.9,
  EUR: 1,
};

function StoreIcon({ iconUrl, alt }: { iconUrl: string | null; alt: string }) {
  const [hasError, setHasError] = useState(false);
  if (!iconUrl || hasError) {
    return <div className="h-5 w-5 shrink-0 rounded bg-white/10" />;
  }
  return (
    <img
      src={iconUrl}
      alt={alt}
      width={20}
      height={20}
      className="h-5 w-5 shrink-0 rounded object-contain"
      onError={() => setHasError(true)}
    />
  );
}

function formatMoney(currency: string | null, amount: number): string {
  const text = amount.toFixed(2);
  if (currency === null) return text;
  const symbol = CURRENCY_SYMBOLS[currency];
  return symbol ? symbol + text : `${text} ${currency}`;
}

const ROW_CLASS =
  "group flex items-center justify-between gap-3 rounded-lg border border-white/20 bg-black px-3 py-2.5 transition-colors hover:border-white/50 hover:bg-white/5";

function SectionLabel({ children }: { children: React.ReactNode }) {
  return (
    <p className="pt-1 text-xs tracking-wide text-gray-400 uppercase">
      {children}
    </p>
  );
}

function GgDealsRow({
  label,
  currency,
  amount,
  url,
}: {
  label: string;
  currency: string | null;
  amount: number;
  url: string | null;
}) {
  const content = (
    <>
      <span className="flex min-w-0 items-center gap-2">
        <Tag className="h-5 w-5 shrink-0 text-gray-400" />
        <span className="truncate text-sm text-white">{label}</span>
      </span>
      <span className="text-sm font-semibold text-white">
        {formatMoney(currency, amount)}
      </span>
    </>
  );
  return url ? (
    <ExternalAnchor href={url} className={ROW_CLASS}>
      {content}
    </ExternalAnchor>
  ) : (
    <div className={ROW_CLASS}>{content}</div>
  );
}

export function GamePriceSection({ steamAppId, title }: GamePriceSectionProps) {
  const [open, setOpen] = useState(false);
  const { data, isLoading, isError } = useGamePrice(steamAppId, open);
  const { data: keyShopOffers, isLoading: keyShopLoading } = useKeyShopPrices(
    title,
    open,
  );

  const info = isError ? undefined : data;
  const hasPrices =
    !!info &&
    (info.currentRetail !== null ||
      info.currentKeyshops !== null ||
      info.historicalRetail !== null ||
      info.historicalKeyshops !== null);
  const hasKeyshopPrices =
    !!info &&
    (info.currentKeyshops !== null || info.historicalKeyshops !== null);
  const offers = [...(keyShopOffers ?? [])].sort(
    (a, b) =>
      a.price * (EUR_PER_UNIT[a.currency] ?? 1) -
      b.price * (EUR_PER_UNIT[b.currency] ?? 1),
  );

  const lowestEver = [
    info?.currentRetail != null &&
    info.historicalRetail != null &&
    info.currentRetail > 0 &&
    info.currentRetail <= info.historicalRetail
      ? { price: info.currentRetail, where: "in the official stores" }
      : null,
    info?.currentKeyshops != null &&
    info.historicalKeyshops != null &&
    info.currentKeyshops > 0 &&
    info.currentKeyshops <= info.historicalKeyshops
      ? { price: info.currentKeyshops, where: "in keyshops" }
      : null,
  ]
    .filter((low) => low !== null)
    .sort((a, b) => a.price - b.price)[0];

  const keyforsteamRow = (
    <ExternalAnchor
      href={`https://www.google.com/search?q=${encodeURIComponent(`site:keyforsteam.de ${title}`)}`}
      className={ROW_CLASS}
    >
      <span className="flex min-w-0 items-center gap-2">
        <Search className="h-5 w-5 shrink-0 text-gray-400" />
        <span className="truncate text-sm text-white">Keyforsteam</span>
      </span>
      <span className="flex shrink-0 items-center gap-2">
        <span className="text-sm text-gray-400">Compare prices</span>
        <ExternalLink className="h-3.5 w-3.5 shrink-0 text-gray-500 opacity-0 transition-opacity group-hover:opacity-100" />
      </span>
    </ExternalAnchor>
  );

  let content: React.ReactNode;
  if (isLoading || keyShopLoading) {
    content = (
      <div className="flex items-center gap-2 text-sm text-gray-400">
        <Loader2 className="h-4 w-4 animate-spin" />
        Loading price...
      </div>
    );
  } else {
    content = (
      <div className="space-y-3 overflow-y-auto pr-1">
        {lowestEver && (
          <div className="flex items-center gap-3 rounded-lg border border-emerald-400/40 bg-emerald-400/10 px-3 py-2.5">
            <Flame className="h-5 w-5 shrink-0 text-emerald-400" />
            <div>
              <p className="text-xs tracking-wide text-emerald-200/80 uppercase">
                Lowest price ever
              </p>
              <p className="text-lg font-bold text-emerald-300">
                {formatMoney(info?.currency ?? null, lowestEver.price)}{" "}
                <span className="text-sm font-normal text-emerald-200/70">
                  {lowestEver.where}
                </span>
              </p>
            </div>
          </div>
        )}
        {!hasPrices && offers.length === 0 && (
          <p className="text-sm text-gray-400">No price data available.</p>
        )}
        {info &&
          (info.currentRetail !== null || info.historicalRetail !== null) && (
            <div className="space-y-2">
              <SectionLabel>Official stores</SectionLabel>
              {info.currentRetail !== null && (
                <GgDealsRow
                  label="Lowest now"
                  currency={info.currency}
                  amount={info.currentRetail}
                  url={info.url}
                />
              )}
              {info.historicalRetail !== null && (
                <GgDealsRow
                  label="Lowest ever"
                  currency={info.currency}
                  amount={info.historicalRetail}
                  url={info.url}
                />
              )}
            </div>
          )}
        {(hasKeyshopPrices || offers.length > 0) && (
          <div className="space-y-2">
            <SectionLabel>Keyshops</SectionLabel>
            {info?.currentKeyshops != null && (
              <GgDealsRow
                label="Lowest now"
                currency={info.currency}
                amount={info.currentKeyshops}
                url={info.url}
              />
            )}
            {info?.historicalKeyshops != null && (
              <GgDealsRow
                label="Lowest ever"
                currency={info.currency}
                amount={info.historicalKeyshops}
                url={info.url}
              />
            )}
            {offers.map((offer) => (
              <ExternalAnchor
                key={offer.shop}
                href={offer.url}
                className={ROW_CLASS}
              >
                <span className="flex min-w-0 items-center gap-2">
                  <StoreIcon
                    iconUrl={KEY_SHOP_ICONS[offer.shop] ?? null}
                    alt={offer.shop}
                  />
                  <span className="truncate text-sm text-white">
                    {offer.shop}
                  </span>
                </span>
                <span className="flex shrink-0 items-center gap-2">
                  <span className="text-sm font-semibold text-white">
                    {formatMoney(offer.currency, offer.price)}
                    {offer.discountPct !== null && offer.discountPct > 0 && (
                      <span className="ml-1.5 text-xs font-normal text-emerald-400">
                        -{offer.discountPct}%
                      </span>
                    )}
                  </span>
                  <ExternalLink className="h-3.5 w-3.5 shrink-0 text-gray-500 opacity-0 transition-opacity group-hover:opacity-100" />
                </span>
              </ExternalAnchor>
            ))}
          </div>
        )}
        <div className="space-y-2">{keyforsteamRow}</div>
        {hasPrices && (
          <ExternalAnchor
            href={info?.url ?? "https://gg.deals"}
            className="text-xs text-gray-400 underline"
          >
            Prices by GG.deals
          </ExternalAnchor>
        )}
      </div>
    );
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button
          type="button"
          variant="outline"
          size="icon"
          aria-label="Show game prices"
          className="shrink-0 border-white/40 bg-black text-white hover:bg-white/10 hover:text-white"
        >
          <Tag className="h-4 w-4" />
        </Button>
      </DialogTrigger>
      <DialogContent
        showCloseButton={false}
        className="flex h-[calc(100vh-6rem)] w-[calc(100vw-6rem)] !max-w-md flex-col border-2 border-white bg-black p-6"
      >
        <DialogClose asChild>
          <Button
            variant="destructive"
            size="icon"
            aria-label="Close price dialog"
            className="absolute top-4 right-4 z-50 h-8 w-8 focus:ring-0 focus:ring-offset-0 focus:outline-none focus-visible:ring-0"
          >
            <XIcon className="h-4 w-4 text-black" />
          </Button>
        </DialogClose>
        <DialogTitle className="flex items-center gap-1.5 text-white">
          <Tag className="h-4 w-4" />
          Price
        </DialogTitle>
        {content}
      </DialogContent>
    </Dialog>
  );
}
