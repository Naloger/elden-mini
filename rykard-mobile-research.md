# Elden Ring (Rykard Sahnesi) → Mobil Mini Oyun Araştırması

Bu doküman; **Elden Ring** PC sürümünden özellikle **Rykard, Lord of Blasphemy** dövüş sahnesine ait 3D model, arena, animasyon ve ses asset'lerinin nasıl çıkarılacağını, mobil cihazlar için nasıl optimize edileceğini, hangi klasik ve yapay zeka (AI) araçlarına ihtiyaç duyulacağını ve **C++ + raylib** (ve alternatiflerinin) **Android APK** hedefi için uygunluğunu özetler.

> [!NOTE]
> **Telif ve Kullanım Notu:** Elden Ring'e ait orijinal model, doku, animasyon ve ses dosyaları FromSoftware / Bandai Namco fikri mülkiyetindedir. Oyun dosyalarından çıkarılan asset'ler yalnızca **kişisel öğrenme, prototipleme ve ticari olmayan deneyler** için kullanılmalıdır. Oyunu Google Play vb. platformlarda yayınlamayı planlıyorsan, çıkarılan asset'leri yalnızca referans olarak kullanıp özgün/ücretsiz/lisanslı modellerle değiştirmen gerekir.

---

## 1. Elden Ring Asset'lerine Nasıl Ulaşılır? (Adım Adım Pipeline)

Elden Ring tüm varlıklarını şifreli/sıkıştırılmış `.bdt` / `.bhd` arşivleri ve `.dcx` konteynerleri içinde tutar. Bu nedenle doğrudan Blender'a atılamazlar; aşağıdaki topluluk araç zinciri izlenir:

### Adım 1: Oyun Dosyalarını Açma (`UXM Selective Unpacker`)
- **Araç:** [UXM Selective Unpacker](https://github.com/Nordgaren/UXM-Selective-Unpack)
- **Ne yapar?** Steam klasöründeki `ELDENRING\Game\eldenring.exe` dosyasını hedef alarak arşivleri açar.
- **İpucu:** Tüm oyunu (~60+ GB) açmak yerine **Selective Unpack** özelliğiyle yalnızca ihtiyacın olan klasörleri (`chr`, `parts`, `map`, `sd`) seçerek disk alanından büyük tasarruf edebilirsin.

### Adım 2: Rykard Sahnesi İçin Hedef Dosya ID'leri
Elden Ring içinde varlıklar dahili ID'lerle tutulur. Rykard dövüşü için odaklanman gereken ana ID'ler:

| Varlık | Dahili ID / Yol | Açıklama |
| :--- | :--- | :--- |
| **Rykard / God-Devouring Serpent** | `c4710` (`chr/c4710.chrbnd.dcx`, `c4710.anibnd.dcx`) | Faz 1 (Yılan) ve Faz 2 (Rykard) ana boss modeli ve animasyonları |
| **Rykard'ın Cesedi (Opsiyonel)** | `c4711` | Boss sonrası sahne durumu |
| **Volcano Manor / Rykard Arenası** | `m16_00_00_00` (`map/m16_00_00_00/`) | Volcano Manor harita grubu (Rykard arenası bu harita uzayında yer alır) |
| **Serpent-Hunter Mızrağı** | `wp_a_0935.partsbnd.dcx` (`parts/`) | Boss'a özel ikonik silah modeli (Weapon ID: `17030000`) |
| **Ses & Müzik** | `sd/` (`.bnk`, `.wem`) | Boss müziği, replikler (`sd/enus/` vb.) ve efektler |

> [!TIP]
> **Smithbox ile Görsel Tespit:** `m16_00_00_00` içinde onlarca parça vardır. Hangisinin Rykard arenası (zemin, kafatası yığınları, sütunlar) olduğunu bulmak için **Smithbox** (DSMapStudio'nun güncel halefi) kullanıp haritayı 3D önizleyerek tam parça adını (`m16_00_00_00_...`) kopyalayabilirsin.

### Adım 3: Konteynerleri Açma (`WitchyBND`)
- **Araç:** `WitchyBND` (Yabber'ın güncel alternatifi)
- `.chrbnd.dcx`, `.partsbnd.dcx` veya `.mapbnd.dcx` dosyalarını `WitchyBND.exe` üzerine sürükleyip bıraktığında:
  - **`.flver`**: 3D mesh + iskelet (rig) dosyası çıkar.
  - **`.tpf`**: Doku (texture) paketi çıkar.
- Çıkan `.tpf` dosyasını da `WitchyBND` üzerine sürükleyerek **`.dds`** formatındaki kaplamaları (Diffuse/Albedo, Normal, Roughness) elde edersin.

### Adım 4: 3D Modelleri Blender'a Aktarma (`FLVER Editor` / `Aqua Toolset`)
- Blender `.flver` formatını doğrudan okuyamaz.
- **FLVER Editor** veya **Aqua Toolset** (`SoulsModelTool`) kullanarak `.flver` → **`.fbx`** dönüştürmesi yapılır.
- Blender'da `File > Import > FBX` ile model alınır, `.dds` kaplamalar `Principled BSDF` düğümüne bağlanır.
  - *Önemli:* Normal ve Roughness haritalarının Blender renk uzayı **Non-Color** olarak ayarlanmalıdır.

### Adım 5: Animasyonları Çıkarma (`DS Anim Studio` + `Havok Toolset`)
- FromSoftware animasyonları Havok (`.hkx`) formatında ve `.anibnd.dcx` içinde saklanır.
- **DS Anim Studio (DSAS):** `c4710` karakterinin hangi animasyon ID'sinin hangi saldırıya (kuyruk savurma, yılan ısırığı, Rykard kılıç kombosu, kafatası yağmuru vb.) karşılık geldiğini görsel olarak bulmanı sağlar.
- **Dönüştürme:** `.hkx` dosyalarını Blender'a aktarmak için topluluk tarafından geliştirilen **Havok Toolset / `hk_to_gltf`** araçları kullanılır; ardından Blender'da model iskeletiyle eşleştirilir.

### Adım 6: Ses ve Müzikleri Çıkarma (`Wwise-Unpacker` / `bnk2json` / `vgmstream`)
- Elden Ring ses motoru olarak **Audiokinetic Wwise** (`.bnk` ve `.wem`) kullanır:
  - `.bnk` ses bankalarını açmak için **`bnk2json`** (veya `bnkextr`) ile içindeki `.wem` dosyaları dışarı çıkarılır.
  - `.wem` dosyalarını `.wav` / `.ogg` formatına çevirmek için **`Wwise-Unpacker`** (`Unpack to OGG.bat`) veya **`foobar2000` + `vgmstream`** eklentisi kullanılır.

---

## 2. Mobil İçin Optimizasyon ve Yapay Zeka (AI) Araçları

PC/Konsol için yapılmış Rykard asset'leri ham haliyle mobil cihazlarda **çalışmaz** (yüksek poligon, dev DDS dokular, çoklu materyal ve karmaşık shader'lar nedeniyle RAM taşması / FPS çökmesi yaşanır).

### Klasik Optimizasyon Araçları
1. **Blender:**
   - **Decimate Modifier / Retopology:** Rykard + arena toplam poligon sayısını mobil bütçeye (örneğin boss ~15k–25k üçgen, arena ~10k–15k üçgen) indirmek için.
   - **Texture Baking & Resize:** Çoklu materyalleri tek bir Texture Atlas'ta birleştirip `512x512` veya `1024x1024` boyutuna küçültmek için.
   - **Export Hazırlığı:** Tek iskelet (single armature) kontrolü ve animasyonların *Always Sample Animations* ile `.glb` (veya `.iqm`) olarak dışa aktarımı.
2. **`gltf-transform` / `meshoptimizer`:** Çıkan `.glb` dosyalarındaki gereksiz node'ları temizlemek ve dosya boyutunu küçültmek için CLI aracı.
3. **Android Studio + NDK + CMake + Gradle:** C++ kodunu APK olarak derlemek ve cihazda test etmek için.
4. **RenderDoc:** Android cihaz üzerinde çizim çağrılarını (draw call) ve shader performansını profillemek için.

### Süreci Hızlandıracak Yapay Zeka (AI) Araçları
- **Animasyon Temizleme & Üretme — `Cascadeur`:**
  - `.hkx` animasyon dönüşümü sırasında kemik yönelimleri bozulursa veya mobil için daha akıcı/basit saldırı animasyonları gerekirse, Cascadeur'un AI fizik/pose yardımcısıyla çok hızlı şekilde temiz boss ve oyuncu animasyonları üretebilirsin.
- **Eksik 3D Parça / Düşük Poligonlu Alternatif — `Meshy.ai` / `Tripo3D` / `Rodin`:**
  - Oyuncu karakteri (şövalye), basit arena kayalıkları veya görsel efekt mesh'leri için sıfırdan modellemek yerine hızlı 3D prototip üretip Blender'da decimate edebilirsin.
- **Doku (Texture) & Efekt — `Materialize` / `ComfyUI (Stable Diffusion)`:**
  - Rykard arenası için tekrar eden (tileable) lav dokusu, yanmış taş zemin ve basit normal map'ler üretmek/iyileştirmek için.
- **Kodlama & Shader Desteği — `Gemini` / `Claude` / `GitHub Copilot`:**
  - Özellikle OpenGL ES 3.0 (`GLSL 300 es`) mobil shader'ları (GPU skinning vertex shader'ı, lav parlaması/emissive, Serpent-Hunter enerji dalgası) ve raylib Android CMake/Gradle kurulumu için.

---

## 3. C++ + raylib ile Android APK Mümkün mü?

**Kısa Cevap:** **Evet, mümkün.** Tek sahnelik, minimalist bir boss-rush mini oyunu için C++ + raylib hem çok hafif (birkaç MB'lık APK) hem de hızlı derlenen harika bir öğrenme/geliştirme ortamı sunar. **Ancak** Rykard gibi iskelet animasyonlu 3D bir boss sahnesinde raylib'in mobil kısıtlarını baştan bilip önlem almak şarttır:

### raylib'in Android & 3D Kısıtları ve Çözümleri

| Konu | Kısıt / Risk | Çözüm / Yaklaşım |
| :--- | :--- | :--- |
| **İskelet Animasyonu (Skinning)** | raylib varsayılan olarak **CPU Skinning** yapar. Rykard gibi çok kemikli bir boss'ta mobil CPU darboğaza girer ve FPS düşer. | raylib'i **`SUPPORT_GPU_SKINNING`** bayrağıyla derleyip matris hesaplamasını OpenGL ES 3.0 GPU vertex shader'ına taşımak gerekir. |
| **glTF Format Sınırları** | `cgltf` entegrasyonu dosya başına **tek armature** destekler; **morph target / blend shape** desteklemez; sadece lineer interpolasyon okur. | Blender'dan tek armature + *Always Sample Animations* ile `.glb` çıkarılmalı; sorun yaşanırsa alternatif olarak raylib'in çok stabil çalıştığı **`.iqm`** formatı kullanılmalı. |
| **Shader & OpenGL ES** | Masaüstü GLSL 330 shader'ları Android'de çalışmaz. | Tüm özel shader'lar (lav, ateş, GPU skinning, ışıklandırma) **OpenGL ES 2.0/3.0 (`GLSL 100` / `300 es`)** uyumlu yazılmalıdır. |
| **VFX & Parçacık Sistemi** | raylib'de yerleşik bir 3D particle system veya post-processing (bloom) yoktur. | Rykard'ın ateş/kafatası ve Serpent-Hunter ışın efektleri için basit billboard quad havuzu + additive blending ve sahte emissive shader yazılmalıdır. |
| **Fizik & Hitbox** | Dahili 3D fizik motoru yoktur. | Tek sahnelik boss dövüşü için tam fizik motoru gerekmez; küre/kapsül (Sphere/Capsule) ve AABB çarpışma matematiği yazmak hem çok kolay hem mobilde çok hızlıdır. |
| **Android Dosya Sistemi** | Normal C++ dosya yolları (`assets/model.glb`) APK içinde doğrudan diskten okunmaz. | Varlıklar `app/src/main/assets/` altına konmalı; raylib'in Android Asset Manager soyutlaması üzerinden `LoadModel()` ile yüklenmelidir. |

---

## 4. Alternatif Framework / Motor Karşılaştırması

Eğer raylib ile GPU skinning shader'ı, parçacık sistemi ve mobil bloom/VFX yazmak senin için fazla zaman alıcı olursa şu alternatifler değerlendirilebilir:

| Seçenek | Dil | Mobil APK Desteği | 3D Animasyon & VFX | Uygunluk Yorumu |
| :--- | :--- | :--- | :--- | :--- |
| **raylib** | C / C++ | NDK + CMake + Gradle | Manuel (GPU Skinning + özel GLES shader gerekir) | **Saf C++ kontrolü, minimum APK boyutu ve düşük seviye grafik öğrenmek** istiyorsan en iyisi. |
| **Godot 4** | GDScript / C++ (GDExtension) | Tek tık Android APK export | Yerleşik glTF 2.0, GPU Skinning, Particle, Shader Graph, Bloom | **En hızlı sonuç ve en iyi görsellik** için güçlü aday. C++ mantığını GDExtension ile yazıp görsel/sahne işini Godot'ya bırakabilirsin. |
| **Unreal Engine 5** | C++ / Blueprint | Var (ağır kurulum) | AAA seviye | Tek sahnelik basit mobil mini oyun için **gereksiz ağır** (büyük APK, yavaş derleme). |
| **bgfx / Sokol** | C++ | NDK / CMake | Çok düşük seviye (her şey manuel) | raylib'den daha esnek ama ilk üçgeni ekrana çizmek bile çok daha fazla boilerplate gerektirir. |

---

## 5. Önerilen Geliştirme Yol Haritası (MVP)

Projeyi boğulmadan ayağa kaldırmak için şu sırayla ilerlemen önerilir:

1. **Faz 1 — Asset Pipeline (Tek Sahne MVP):**
   - `UXM` + `WitchyBND` + `FLVER Editor` ile `c4710` (Rykard), `wp_a_0935` (Serpent-Hunter) ve `m16_00_00_00` arenasının sadece zemin/çevre parçasını çıkar.
   - Blender'da poligonları düşür (~20k üçgen hedefi), dokuları 1024x1024 PNG'ye çevir, tek armature ile 3-4 temel animasyon (Idle, Kuyruk/Kafa Saldırısı, Ölüm) içeren `.glb` üret.
2. **Faz 2 — Masaüstü C++ raylib Prototipi (Windows):**
   - Önce `dev` branch'inde Windows üzerinde C++ + raylib ile modeli yükle, `SUPPORT_GPU_SKINNING` shader'ını test et, kamera + basit oyuncu hareketi + dodge/saldırı + hitbox çarpışmasını çalışır hale getir.
3. **Faz 3 — Android APK Derlemesi:**
   - Android NDK + CMake + Gradle şablonunu kur, `.glb` ve `.ogg` dosyalarını `assets/` içine koy, gerçek Android telefonda FPS ve bellek kullanımını ölç.
4. **Faz 4 — Atmosfer & Cilalama:**
   - Boss can barı, faz geçişi veya basit lav/ateş billboard efektleri, Serpent-Hunter enerji dalgası shader'ı ve dokunmatik (sanal joystick + saldırı/dodge) butonları ekle.
