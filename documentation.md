# Parametra AI: Ürün ve Teknik Dökümantasyon
**Versiyon:** 1.0.0  
**Durum:** Üretim Hazır  
**Kapsam:** Sistem Mimarisi, AI Entegrasyonu ve Modüler Yapı

---

## 1. Uygulama Genel Tanıtımı

### 1.1 Uygulamanın Amacı
Parametra AI, kullanıcının finansal durumunu, sağlık alışkanlıklarını, borçlarını, hedeflerini ve günlük notlarını tek bir çatı altında toplayan; bu verileri **Gemini AI** altyapısıyla analiz ederek kişiye özel yaşam stratejileri sunan "Hepsi Bir Arada" dijital yaşam asistanıdır.

### 1.2 Hedef Kullanıcı Kitlesi
- Finansal disiplin kazanmak isteyen bireyler.
- Sağlık alışkanlıklarını (su içme, ilaç takibi, sigara bırakma) düzene sokmak isteyenler.
- Dağınık verilerini (notlar, borçlar, hedefler) tek bir yapay zeka ile yönetmek isteyen teknoloji meraklıları.

### 1.3 Temel Özellikler
- **Veri Odaklı Analiz:** Modüller arası veri geçişiyle bütünsel yaşam özeti.
- **AI Komut Sistemi:** Sesli veya yazılı komutla veri işleme (Örn: "50 TL yemek harcaması gir").
- **Görsel Raporlama:** AI destekli aylık PDF yaşam raporları.
- **Motivasyon:** Rozet sistemi ve gelişim takibi.

---

## 2. Modüller ve Sistem Yapısı

| Modül | Temel İşlev | AI Entegrasyonu | Bildirim Sistemi |
| :--- | :--- | :--- | :--- |
| **Finans** | Gelir/Gider takibi, bütçe yönetimi. | Harcama analizi ve bütçe tahminleme. | Bütçe aşımı uyarıları. |
| **Borç / Alacak** | Vade takibi ve ödeme planı. | Ödeme gücü analizi ve önceliklendirme. | Vade hatırlatıcıları. |
| **Sağlık** | Su tüketimi ve günlük alışkanlıklar. | Dehidrasyon riski ve su içme önerileri. | Periyodik su hatırlatıcılar. |
| **İlaç Takibi** | İlaç dozaj ve stok takibi. | Kullanım düzeni analizi. | Kritik doz hatırlatıcılar. |
| **Sigara** | Bırakılan gün ve tasarruf takibi. | Sağlık kazanımı ve finansal geri dönüş raporu. | Motivasyonel başarı kutlamaları. |
| **Notlar** | Hızlı not alma ve kategorizasyon. | Not içeriklerinden aksiyon çıkarma. | Hatırlatıcı notlar. |
| **Hedefler** | İlerleme takibi (Finansal/Kişisel). | Hedefe ulaşma olasılığı ve strateji önerisi. | İlerleme raporları. |

---

## 3. AI Sistemi (The Parametra Brain)

### 3.1 Çalışma Mantığı
Parametra AI, **Google Gemini Flash 1.5** modelini kullanır. Sistemin kalbi olan `AiAssistantService`, kullanıcının tüm modüllerdeki verilerini anlık olarak "Context" haline getirir ve AI'ya besler.

### 3.2 Prompt Sistemi ve Veri Analizi
- **Context Injection:** AI'ya her istekte kullanıcının güncel finansal bakiyesi, aktif borçları ve sağlık verileri gönderilir.
- **Aksiyon Tespiti:** AI, kullanıcı mesajından JSON formatında aksiyonlar üretir: `[ACTION: {"type": "add_expense", "amount": 100}]`.
- **Token Optimizasyonu:** Veriler sadece özetlenmiş ve gerekli kısımlarıyla AI'ya iletilerek performans ve maliyet dengesi sağlanır.

---

## 4. Premium ve Abonelik Sistemi

### 4.1 Abonelik Katmanları
1. **Ücretsiz (Free):** Temel kayıt özellikleri, sınırlı modül kullanımı.
2. **Premium:** Sınırsız kayıt, reklam kaldırma, tüm modüllere erişim.
3. **Platinum AI:** Tüm Premium özellikler + **Sınırsız AI Asistan**, Sesli Komut ve AI Yaşam Raporları.

### 4.2 Trial ve Ödeme Akışı
- **30 Günlük Deneme:** Yeni kullanıcılar için Firestore üzerinden yönetilen dinamik deneme süresi.
- **Mağaza Entegrasyonu:** `in_app_purchase` ile App Store ve Play Store üzerinden güvenli ödeme.

---

## 5. Teknik Altyapı ve Teknolojiler

- **Frontend:** Flutter (Dart) - Riverpod (State Management).
- **Backend:** Firebase (Firestore, Auth, Storage).
- **AI:** Google Generative AI (Gemini API).
- **Yerel Servisler:** 
    - `flutter_local_notifications` (Bildirimler).
    - `speech_to_text` (Sesli komut).
    - `pdf` & `printing` (Raporlama).
    - `home_widget` (Android Widget desteği).

---

## 6. Veri Yapısı (Firestore Schema)

```
/users/{userId}
  ├── profile (Kullanıcı bilgileri, para birimi)
  ├── subscription (Durum, bitiş tarihi, trial bilgisi)
  ├── finance_actions (Harcama ve gelirler)
  ├── debts (Borç ve alacak kayıtları)
  ├── health (Su tüketimi, ilaçlar)
  ├── goals (İlerleme verileri)
  └── ai_messages (Sohbet geçmişi)
```

---

## 7. Güvenlik ve Gizlilik

### 7.1 Veri Yönetimi
- **Kullanıcı İzinleri:** Mikrofon, bildirim ve galeri erişimi kullanıcı onayına bağlıdır.
- **Hesap Silme:** Kullanıcılar tüm verilerini ve hesaplarını uygulama içinden kalıcı olarak silebilir (KVKK uyumu).
- **Gizlilik:** Kişisel veriler sadece Firebase Authentication ile yetkilendirilmiş kullanıcıya özeldir.

---

## 8. Gelecek Yol Haritası (Roadmap)

- **AI Geliştirmeleri:** Sesli yanıt verme (Text-to-Speech) yeteneği.
- **Görsel Analiz:** Mutfak fişi/fatura fotoğrafından otomatik harcama girişi.
- **Eko-sistem:** iOS Widget ve Apple Watch entegrasyonu.
- **Sosyal:** Kullanıcılar arası (isteğe bağlı) anonim başarı sıralamaları.

---
*Bu döküman Parametra AI sistem mimarisini ve ürün vizyonunu temsil eder.*
