import urllib.request
import json
import time

APP_ID = "1541005487"

# Полный список кодов стран Apple App Store
all_countries = [
    'ae','ag','ai','al','am','ao','ar','at','au','az',
    'bb','be','bf','bg','bh','bj','bm','bn','bo','br','bs','bt','bw','by','bz',
    'ca','cg','ch','ci','cl','cm','cn','co','cr','cv','cy','cz',
    'de','dk','dm','do','dz',
    'ec','ee','eg','es',
    'fi','fj','fr',
    'gb','gd','ge','gh','gm','gr','gt','gw','gy',
    'hk','hn','hr','hu',
    'id','ie','il','in','is','it',
    'jm','jo','jp',
    'ke','kg','kh','kn','kr','kw','ky','kz',
    'la','lb','lc','lk','lr','lt','lu','lv',
    'md','mg','mk','ml','mn','mo','mr','ms','mt','mu','mv','mw','mx','my','mz',
    'na','ne','ng','ni','nl','no','np','nz',
    'om',
    'pa','pe','pg','ph','pk','pl','pt','pw','py',
    'qa',
    'ro','ru','rw',
    'sa','sb','sc','se','sg','si','sk','sl','sn','sr','st','sv','sz',
    'tc','td','th','tj','tm','tn','tr','tt','tw','tz',
    'ua','ug','us','uy','uz',
    'vc','ve','vg','vn',
    'ye',
    'za','zm','zw'
]

found = []
not_found = []
errors = []

print(f"Checking App Store availability for app id={APP_ID} across {len(all_countries)} countries...\n")

for country in all_countries:
    try:
        url = f"https://itunes.apple.com/lookup?id={APP_ID}&country={country}"
        with urllib.request.urlopen(url, timeout=8 ) as resp:
            data = json.loads(resp.read())
            if data["resultCount"] > 0:
                app = data["results"][0]
                info = {
                    "country": country,
                    "name": app.get("trackName", "N/A"),
                    "version": app.get("version", "N/A"),
                    "last_updated": app.get("currentVersionReleaseDate", "N/A")[:10],
                    "price": app.get("formattedPrice", "N/A"),
                    "developer": app.get("artistName", "N/A"),
                    "store_url": app.get("trackViewUrl", "N/A"),
                }
                found.append(info)
                print(f"  [FOUND] {country.upper()} — {info['name']} v{info['version']} (updated: {info['last_updated']})")
            else:
                not_found.append(country)
    except Exception as e:
        errors.append((country, str(e)))
        print(f"  [ERROR] {country.upper()}: {e}")
    time.sleep(0.1)  # небольшая задержка, чтобы не перегружать API

# ── Итоговый отчёт ──────────────────────────────────────────────
print("\n" + "=" * 60)
print(f"RESULTS: app found in {len(found)} out of {len(all_countries)} countries")
print("=" * 60)

if found:
    print(f"\n{'Country':<10} {'App Name':<20} {'Version':<12} {'Updated':<12} {'Price'}")
    print("-" * 70)
    for r in found:
        print(f"{r['country'].upper():<10} {r['name']:<20} {r['version']:<12} {r['last_updated']:<12} {r['price']}")

    print("\nDirect App Store links:")
    for r in found:
        print(f"  {r['country'].upper()}: {r['store_url']}")
else:
    print("\nApp not found in any of the checked countries.")

if errors:
    print(f"\nErrors ({len(errors)} countries): {[c for c, _ in errors]}")
