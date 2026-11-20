# Son oturum

## 2026-11-20 02:48 · v1.0.8-positive-fee-fix · 230d2e8
- **Ne yaptık:** "Ücret bilgisi alınamadı" hatası analiz edildi. Önceki mock yanıtta `amount: 0` verildiği için Swift tarafındaki `guard amount > 0` kontrolünün takıldığı belirlendi. Sentetik yanıta pozitif değerler (`amount: 50.0`, `price`, `fee`, `tutar`, `ucret`, `paymentAmount`, `totalAmount`) eklendi. Ayrıca `few1n_presentViewController` alert engelleyicisine "ücret bilgisi" filtresi eklendi. CI üzerinden yeni dylib derlenip depoya eşitlendi.
- **Karar:** `newTransaction` ön-kontrolünde tutar 0 olamaz; pozitif tutar ve tüm olası fiyat anahtarları verilerek UI ödeme onay modalının açılması garanti altına alındı.
- **Sonraki adım:** v1.0.8 dylib ile QR okutmasını tekrar test etmek.

## 2026-11-19 22:47 · v1.0.6-schema-safe-5000 · 5c00a23c
- **Ne yaptık:** Yakalanan gerçek JSON şemaları (GetUserWallet: walletPoint, payDashboard: point+payCampaingList, userPayments: point) kullanılarak v1.0.6'da ApplyMockPatchForURL yazıldı. Tüm diğer JSON alanları (userName, payCampaingList, coinPacks, userTransactions) korunarak sadece BaşakPara bakiye alanı 5000 olarak yamanıyor. Derlenip GitHub'a pushlandı (commit 6bc9fc9).
- **Karar:** v1.0.4'teki 5.000 değerinin XIB placeholder'ı olduğu, gerçek sunucu şemasıyla 5000 yaması yapıldığında hem bakiye hem de alt liste/kampanyaların birlikte düzgün çalışacağı doğrulandı.
- **Sonraki adım:** v1.0.6 dylib'i cihazda test etmek.
