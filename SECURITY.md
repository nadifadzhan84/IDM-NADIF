# Kebijakan Keamanan

Dokumen ini menjelaskan cara melaporkan masalah keamanan kepada pemelihara repositori secara privat. Jangan pernah mempublikasikan detail kerentanan melalui issue terbuka sebelum masalah tersebut diperbaiki.

## Versi yang Didukung

Perbaikan keamanan hanya disediakan untuk **rilis terbaru**. Saat ini versi yang didukung adalah **v1.9.5**.

## Cara Melaporkan Kerentanan

1. **Disarankan**: buka tab `Security` pada repositori GitHub, lalu pilih `Report a vulnerability` untuk mengirim Security Advisory secara privat.
2. **Alternatif**: hubungi pemilik repositori melalui fitur pesan GitHub jika jalur di atas tidak tersedia.

## Informasi yang Sebaiknya Disertakan

Agar proses analisis lebih cepat, sertakan informasi berikut dalam laporan:

- deskripsi masalah dan potensi dampaknya;
- langkah reproduksi minimal, termasuk versi Windows, versi IDM, parameter yang dijalankan, dan log terkait;
- file atau versi yang terdampak, misalnya commit SHA atau tag rilis;
- usulan perbaikan awal, bila ada.

## Waktu Respons dan Alur Penanganan

- Pemelihara akan berusaha memberikan tanggapan awal dalam waktu **7 hari**.
- Setelah masalah dikonfirmasi, pemelihara akan menyusun perkiraan jadwal perbaikan bersama pelapor, dengan target rilis perbaikan dalam rentang waktu yang wajar.
- Detail kerentanan tidak akan dipublikasikan tanpa persetujuan pelapor. Setelah rilis perbaikan terbit, ucapan terima kasih dapat dicantumkan di `CHANGELOG.md` jika pelapor berkenan.

## Cakupan

Kebijakan ini **mencakup**:

- potensi code injection, command injection, atau path traversal pada skrip;
- perilaku yang dapat memicu perubahan sistem tak terduga, kehilangan data, atau kebocoran kredensial;
- masalah integritas pada artefak rilis seperti file zip.

Kebijakan ini **tidak mencakup**:

- masalah yang berasal dari lingkungan pengguna sendiri, misalnya PowerShell yang sudah dimodifikasi atau `cmd.exe` yang telah diganti;
- deteksi heuristik antivirus terhadap skrip ini, karena hal tersebut termasuk friksi operasional dan bukan kerentanan keamanan langsung.

## Jangan Ungkapkan Secara Publik Sebelum Diperbaiki

Sebelum pemelihara menyatakan masalah telah diperbaiki dan versi perbaikannya dirilis, mohon jangan membagikan detail teknis kerentanan di forum, blog, atau issue publik.
