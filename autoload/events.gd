extends Node
## Oyun genelinde kullanılan sinyal veri yolu. Sistemler birbirini doğrudan
## tanımadan haberleşir (örn. HUD bildirimleri, oyuncu ölümü).

## Ekranın sol altında kısa süre görünen bildirim.
signal notify(text: String)
signal player_damaged(amount: float)
signal player_died(cause: String)
signal game_saved
## Oyuncunun baktığı nesne için etkileşim ipucu. Boş metin ipucunu gizler.
## progress 0..1 arası basılı tutma ilerlemesidir, -1 ise çubuk gösterilmez.
signal interaction_changed(text: String, progress: float)
