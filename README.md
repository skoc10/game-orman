# ORMAN

Issız bir ormanda tek başına hayatta kalma oyunu. Birinci şahıs, low-poly, Godot 4 ile yapıldı.

The Forest'tan esinlendi ama **zombi, yamyam ya da gece saldırısı yok**. Tehlike doğadan gelir: kurtlar, açlık, susuzluk, soğuk ve karanlık. Oyunun sonu yok; amaç olabildiğince çok gün hayatta kalmak.

## Gereksinimler

- [Godot 4.7.2](https://godotengine.org/) (macOS: `brew install --cask godot`)

## Çalıştırma

```bash
godot --path .
```

Editörde açmak için:

```bash
godot --editor --path .
```

## Testler

Birim testleri [GUT](https://github.com/bitwes/Gut) ile headless çalışır:

```bash
./tools/test.sh
```

## Klasörler

| Klasör | İçerik |
|---|---|
| `autoload/` | Her yerden erişilen tekil sistemler: saat, kayıt, eşya veritabanı, girdi |
| `data/` | Eşya ve tarif `.tres` dosyaları, denge ayarları (`balance.tres`) |
| `world/` | Prosedürel ada, su, bitki örtüsü, gece/gündüz |
| `player/` | Oyuncu hareketi, istatistikler, envanter, etkileşim, inşa |
| `crafting/` | Eşya/tarif sınıfları, crafting ve pişirme mantığı |
| `buildables/` | Kamp ateşi, barınak, sandık |
| `animals/` | Geyik, kurt ve ortak davranış makinesi |
| `ui/` | HUD ve menüler |
| `tools/` | Test ve hata ayıklama araçları |
| `tests/` | Birim testleri |

Görsel ve ses kaynakları için [CREDITS.md](CREDITS.md) dosyasına bakın.
