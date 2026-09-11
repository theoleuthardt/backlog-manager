"use client";
import { useState } from "react";
import Image from "next/image";
import {
  ExternalLink,
  Flame,
  Loader2,
  Search,
  Tag,
  TrendingDown,
  XIcon,
} from "lucide-react";
import { useGamePrice, useKeyShopPrices } from "~/hooks/useGameSearch";
import { env } from "~/env";
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

function StoreIcon({ iconUrl, alt }: { iconUrl: string; alt: string }) {
  const [hasError, setHasError] = useState(false);
  if (!iconUrl || hasError) {
    return <div className="h-5 w-5 shrink-0 rounded bg-white/10" />;
  }
  return (
    <Image
      src={`${env.NEXT_PUBLIC_API_URL}/api/images/proxy?url=${encodeURIComponent(iconUrl)}`}
      alt={alt}
      width={20}
      height={20}
      unoptimized
      className="h-5 w-5 shrink-0 rounded object-contain"
      onError={() => setHasError(true)}
    />
  );
}

export function GamePriceSection({ steamAppId, title }: GamePriceSectionProps) {
  const [open, setOpen] = useState(false);
  const { data, isLoading, isError } = useGamePrice(steamAppId, open);
  const { data: keyShopOffers } = useKeyShopPrices(title, open);

  if (steamAppId === undefined) return null;

  const hasCheapSharkDeals = !isError && !!data && data.deals.length > 0;
  const hasKeyShopOffers = !!keyShopOffers && keyShopOffers.length > 0;

  interface PriceListing {
    key: string;
    store: string;
    iconUrl: string | null;
    price: number;
    retailPrice: number | null;
    discountPct: number | null;
    url: string;
  }

  const listings: PriceListing[] = [
    ...(data?.deals.map((deal) => ({
      key: `cheapshark-${deal.store}`,
      store: deal.store,
      iconUrl: deal.iconUrl,
      price: deal.price,
      retailPrice: deal.retailPrice,
      discountPct: null,
      url: deal.url,
    })) ?? []),
    ...(keyShopOffers?.map((offer) => ({
      key: `keyshop-${offer.shop}`,
      store: offer.shop,
      iconUrl: offer.imageUrl,
      price: offer.price,
      retailPrice: null,
      discountPct: offer.discountPct,
      url: offer.url,
    })) ?? []),
  ].sort((a, b) => a.price - b.price);

  let content: React.ReactNode;
  if (isLoading) {
    content = (
      <div className="flex items-center gap-2 text-sm text-gray-400">
        <Loader2 className="h-4 w-4 animate-spin" />
        Loading price...
      </div>
    );
  } else if (!hasCheapSharkDeals && !hasKeyShopOffers) {
    content = <p className="text-sm text-gray-400">No price data available.</p>;
  } else {
    const cheapest =
      hasCheapSharkDeals && data
        ? data.deals.reduce((lowest, deal) =>
            deal.price < lowest.price ? deal : lowest,
          )
        : null;
    const discountPercent = cheapest
      ? Math.round((1 - cheapest.price / cheapest.retailPrice) * 100)
      : 0;
    content = (
      <div className="space-y-3 overflow-y-auto pr-1">
        {data?.onSale && cheapest && (
          <div className="flex items-center gap-3 rounded-lg border border-emerald-400/40 bg-emerald-400/10 px-3 py-2.5">
            <Flame className="h-5 w-5 shrink-0 text-emerald-400" />
            <div>
              <p className="text-xs tracking-wide text-emerald-200/80 uppercase">
                On Sale Now{discountPercent > 0 && ` -${discountPercent}%`}
              </p>
              <p className="text-lg font-bold text-emerald-300">
                €{cheapest.price.toFixed(2)}{" "}
                <span className="text-sm font-normal text-emerald-200/70">
                  at {cheapest.store}
                </span>
              </p>
            </div>
          </div>
        )}
        {data?.cheapestPriceEver != null && (
          <div className="flex items-center gap-3 rounded-lg border border-amber-400/40 bg-amber-400/10 px-3 py-2.5">
            <TrendingDown className="h-5 w-5 shrink-0 text-amber-400" />
            <div>
              <p className="text-xs tracking-wide text-amber-200/80 uppercase">
                All-Time Low
              </p>
              <p className="text-lg font-bold text-amber-300">
                €{data.cheapestPriceEver.toFixed(2)}
              </p>
            </div>
          </div>
        )}
        <div className="space-y-2">
          <a
            href={`https://www.google.com/search?q=${encodeURIComponent(`site:keyforsteam.de ${title}`)}`}
            target="_blank"
            rel="noopener noreferrer"
            className="group flex items-center justify-between gap-3 rounded-lg border border-white/20 bg-black px-3 py-2.5 transition-colors hover:border-white/50 hover:bg-white/5"
          >
            <span className="flex min-w-0 items-center gap-2">
              <Search className="h-5 w-5 shrink-0 text-gray-400" />
              <span className="truncate text-sm text-white">Keyforsteam</span>
            </span>
            <span className="flex shrink-0 items-center gap-2">
              <span className="text-sm text-gray-400">Compare prices</span>
              <ExternalLink className="h-3.5 w-3.5 shrink-0 text-gray-500 opacity-0 transition-opacity group-hover:opacity-100" />
            </span>
          </a>
          {listings.map((listing) => (
            <a
              key={listing.key}
              href={listing.url}
              target="_blank"
              rel="noopener noreferrer"
              className="group flex items-center justify-between gap-3 rounded-lg border border-white/20 bg-black px-3 py-2.5 transition-colors hover:border-white/50 hover:bg-white/5"
            >
              <span className="flex min-w-0 items-center gap-2">
                {listing.iconUrl !== null ? (
                  <StoreIcon iconUrl={listing.iconUrl} alt={listing.store} />
                ) : (
                  <div className="h-5 w-5 shrink-0 rounded bg-white/10" />
                )}
                <span className="truncate text-sm text-white">
                  {listing.store}
                </span>
              </span>
              <span className="flex shrink-0 items-center gap-2">
                <span className="text-sm font-semibold text-white">
                  €{listing.price.toFixed(2)}
                  {listing.retailPrice !== null &&
                    listing.retailPrice > listing.price && (
                      <span className="ml-1.5 text-xs font-normal text-gray-500 line-through">
                        €{listing.retailPrice.toFixed(2)}
                      </span>
                    )}
                  {listing.discountPct !== null && listing.discountPct > 0 && (
                    <span className="ml-1.5 text-xs font-normal text-emerald-400">
                      -{listing.discountPct}%
                    </span>
                  )}
                </span>
                <ExternalLink className="h-3.5 w-3.5 shrink-0 text-gray-500 opacity-0 transition-opacity group-hover:opacity-100" />
              </span>
            </a>
          ))}
        </div>
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
