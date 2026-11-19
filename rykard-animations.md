# Rykard (`c4710`) İskelet ve Animasyon Sekansları Haritası

Bu doküman, `rykard.glb` (`c4710.flver`) içindeki `Skeleton3D` kemik hiyerarşisini ve **Faz 1 (God-Devouring Serpent)** / **Faz 2 (Rykard, Lord of Blasphemy)** saldırı animasyonlarının kemik bazlı karşılıklarını belgeler.

## 1. Tespit Edilen Ana Kemik Zinciri (`Skeleton3D`)

| Kemik Grubu | Kemik İsimleri | Hiyerarşi | Görevi |
| :--- | :--- | :--- | :--- |
| **Ana Yılan Omurgası** | `Body2_04` → `Body2_03` → `Body2_02` → `Body2_01` | Zincirli (`parent` bağlı) | Gövde yükselmesi, şahlanma, sağ/sol savrulma |
| **Boyun & Yılan Başı** | `Body1_04` → `Body1_03` → `Body1_02` → `Body1_01` → `Head21` | Zincirli (`parent=11` devamı) | Isırık atılımı, kükreme, kafa vuruşu |
| **Yılan Çenesi** | `Jaw21` | `Head21` altında | Çene açılma / ısırık kapanması (`0° → 55°`) |
| **Rykard İnsan Yüzü** | `Head11`, `Jaw11` | `Body2_01` altında | Faz 2 kükreme ve baş hareketi |
| **Dev Kollar & Kılıç** | `R UpperArmSub`, `L UpperArmSub`, `Ctrl_R_Sword1` | Kök kemikler (`parent=-1`) | Blasphemous Blade kaldırma, yatay savurma ve yere vurma |

---

## 2. Faz 1 — God-Devouring Serpent Animasyon Sekansları

| Durum (`State`) | Süre | Kemik Hareketi | Oynanış Etkisi |
| :--- | :--- | :--- | :--- |
| `IDLE` | 0.95s | Omurga sinüzoidal salınım (`±12°`), çene nefes | Bekleme ve oyuncuyu takip |
| `TELEGRAPH` | 0.85s | `Body2/Body1` geriye şahlanma (`-45°`), `Jaw21` tam açık (`+48°`) | Kırmızı uyarı halkası |
| `P1_BITE_LUNGE` | 0.52s | Omurga + boyun hızla öne atılır (`+50°`), çene kapanır | Yakın menzil ısırık hasarı |
| `P1_MULTI_BITE` | 1.25s | 3 hızlı sağ-sol-merkez kafa/çene hamlesi (`sin(t*3π)`) | 3'lü kombo ısırık |
| `P1_BODY_SLAM` | 1.00s | Gövde `+2.1m` yükselip sertçe zemine çarpar | Kamera sarsıntısı + yakın alan + şok dalgası |
| `P1_MAGMA_SPIT` | 0.65s | Boyun geriye çekilir, çene titreşerek açık kalır | 4 adet lav topu → geçici lav havuzu |
| `P1_SERPENT_SWEEP` | 0.65s | Omurga `-55° → +65°` Y-ekseni süpürme | Genişleyen lav şok dalgası |

---

## 3. Faz 2 — Rykard, Lord of Blasphemy Animasyon Sekansları (`≤ %55 HP`)

| Durum (`State`) | Süre | Kemik Hareketi | Oynanış Etkisi |
| :--- | :--- | :--- | :--- |
| `P2_SWORD_COMBO` | 1.05s | `R_Sword1` + `R UpperArmSub` + omurga 2'li geniş yatay kombo | Çift kılıç savurma + yay boyunca gecikmeli alev patlamaları |
| `P2_TAKERS_FLAMES` | 1.00s | Kılıç ve kollar tepeye kalkar (`-65°`), ardından sertçe yere iner (`+70°`) | Oyuncu hattında 7 adet patlayan alev sütunu |
| `P2_RYKARDS_RANCOR` | 0.75s | Kollar ve baş göğe kalkar, çene açık kükreme | 5 adet takip eden kızıl kafatası |
| `P2_RAIN_OF_SKULLS` | 2.80s | Gövde dikilir, kılıç havada titrer, sürekli kükreme | Tepeden sürekli yağan kafatası yağmuru |
| `STAGGERED` | 1.80s | Omurga ve kollar öne düşer (`+40°`), baş eğilir | 360 poise (4 Serpent-Hunter vuruşu) sonrası büyü kesilir |
