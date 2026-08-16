import { Tv, ShoppingCart, ArrowUpRight } from "lucide-react";

function ProviderRow({ label, icon: Icon, providers }) {
  if (!providers?.length) return null;

  return (
    <div className="flex items-start gap-3 px-4 py-3">
      <Icon className="w-5 h-5 text-ios-tertiary-label mt-0.5" />
      <div className="flex-1 min-w-0">
        <p className="text-ios-caption1 text-ios-tertiary-label mb-1.5">{label}</p>
        <div className="flex flex-wrap gap-2">
          {providers.map((provider) => (
            <span
              key={provider.id ?? provider.name}
              className="inline-flex items-center gap-1.5 rounded-full bg-ios-fill px-2.5 py-1 text-ios-caption1 text-ios-label"
            >
              {provider.logo && (
                <img
                  src={provider.logo}
                  alt=""
                  className="w-4 h-4 rounded-[4px] object-cover"
                />
              )}
              {provider.name}
            </span>
          ))}
        </div>
      </div>
    </div>
  );
}

export default function WatchProviders({ watchProviders }) {
  if (!watchProviders) return null;

  const { stream, rent, buy, link } = watchProviders;
  if (!stream?.length && !rent?.length && !buy?.length) return null;

  return (
    <div className="px-4 pb-4">
      <h2 className="text-ios-headline font-semibold text-ios-label mb-2">Where to Watch</h2>
      <div className="ios-card divide-y divide-ios-separator">
        <ProviderRow label="Stream" icon={Tv} providers={stream} />
        <ProviderRow label="Rent" icon={ShoppingCart} providers={rent} />
        <ProviderRow label="Buy" icon={ShoppingCart} providers={buy} />

        {link && (
          <a
            href={link}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-3 px-4 py-3 active:bg-ios-fill-tertiary transition-colors"
          >
            <ArrowUpRight className="w-5 h-5 text-ios-blue" />
            <div className="flex-1">
              <p className="text-ios-body text-ios-blue">More watch options</p>
            </div>
          </a>
        )}
      </div>
    </div>
  );
}
