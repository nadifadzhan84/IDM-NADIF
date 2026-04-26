# Catatan Perubahan

Dokumen ini mencatat semua perubahan yang dirilis untuk IDM Activation Script. Penomoran versi mengikuti gaya [Semantic Versioning](https://semver.org/lang/zh-CN/): `mayor.minor.patch`.

- Format: setiap versi dapat berisi bagian `Baru / Perubahan / Perbaikan / Dokumentasi / Kompatibilitas`, sesuai kebutuhan.
- Tanggal menggunakan zona waktu lokal repositori.
- Versi terbaru selalu ditempatkan di bagian paling atas.

---

## v1.9.8 - 2026-04-26

### Baru
- `tools_nadif/popup_watcher.ps1`: pengawas popup "fake Serial Number" IDM berbasis Win32 API. Menggunakan `EnumWindows` + `EnumChildWindows` untuk memindai jendela dialog (`#32770`) berjudul `Internet Download Manager` yang memuat teks `fake Serial Number` atau `Serial Number has been blocked`, lalu mengirim `WM_CLOSE` via `PostMessage`. Jendela IDM utama dan dialog `This product is licensed to ... This is a lifetime license` tidak pernah disentuh karena teksnya berbeda. Log ringkas ditulis ke `%LOCALAPPDATA%\IAS-NADIF\popup_watcher.log`.
- `IAS.cmd`: subrutin baru `:install_popup_watcher` dan `:uninstall_popup_watcher`. Watcher disalin ke `%ProgramData%\IAS-NADIF\popup_watcher.ps1`, lalu didaftarkan sebagai Scheduled Task `IAS-NADIF-PopupWatcher` (trigger: onlogon, user sekarang, `WindowStyle Hidden`, `rl limited`). Watcher juga di-spawn langsung di sesi saat ini sehingga popup yang sedang nongol dapat segera ditutup. Task dihentikan secara kooperatif melalui file sinyal `%ProgramData%\IAS-NADIF\stop.flag` (watcher mengecek flag tiap iterasi).
- Hook baru pada `:_activate` alur **Normal** (baris 698): setelah `:register_IDM`, `:install_popup_watcher` dipanggil agar popup fake-serial yang lolos blok hosts tetap ditutup otomatis.
- Hook baru pada `:_reset` sebagai langkah `STEP 06 Mencopot pengawas popup fake-serial`: menghentikan watcher via stop.flag, menghapus Scheduled Task, dan membersihkan `%ProgramData%\IAS-NADIF`.

### Kompatibilitas
- Popup watcher hanya menargetkan dialog dengan kelas window `#32770` + judul persis `Internet Download Manager` + teks anak yang cocok dengan pola fake-serial. Tidak ada risiko menutup jendela lain milik IDM atau aplikasi lain yang kebetulan berjudul sama tetapi tanpa teks pemicu.
- Semua operasi Scheduled Task idempoten: `:install_popup_watcher` meng-`end` + `delete` task lama dan membunuh instance watcher lama via stop.flag sebelum memasang ulang, sehingga pemanggilan berulang aman.
- Nama Scheduled Task konsisten `IAS-NADIF-PopupWatcher` agar mudah dicari atau dihapus manual via `schtasks /query /tn "IAS-NADIF-PopupWatcher"`.

---

## v1.9.7 - 2026-04-25

### Baru
- `Test_Script.cmd`: pemeriksaan baru "bypass popup fake-serial". Verifier membaca `%SystemRoot%\System32\drivers\etc\hosts`, memastikan marker `# IAS-NADIF-BLOCK START`/`END` hadir dan entri `0.0.0.0 registeridm.com` serta `0.0.0.0 tonec.com` sudah terpasang. Bit keluar baru `ERR_HOSTS_BYPASS=1024` ditambahkan agar otomatisasi bisa membedakan "bypass belum terpasang" dari kegagalan lain.
- Apabila tidak ada marker sama sekali, pemeriksaan hanya memberi catatan informatif tanpa menandai gagal, sehingga user yang belum menjalankan `Quick_Activation.cmd` / `Normal_Activation.cmd` tidak kaget dengan kode keluar non-zero.
- `release/IDM-Activation-Script-v1.9.7.zip` di-pack ulang dari file terbaru di `main` (IAS.cmd 1.9.7, CHANGELOG, Test_Script.cmd dengan verifier bypass, README, dll) beserta `sha256` pendampingnya. Zip v1.9.5 lama tetap dibiarkan sebagai arsip.

---

## v1.9.6 - 2026-04-25

### Baru
- `IAS.cmd`: subrutin baru `:block_idm_hosts` yang otomatis menulis entri bypass ke `%SystemRoot%\System32\drivers\etc\hosts` agar popup "Internet Download Manager has been registered with a fake Serial Number" tidak muncul lagi setelah 3-5 unduhan. Domain yang diblok: `registeridm.com`, `www.registeridm.com`, `secure.registeridm.com`, `tonec.com`, `www.tonec.com`, `secure.tonec.com`, serta mirror `mirror.internetdownloadmanager.com`, `mirror2.internetdownloadmanager.com`, `mirror3.internetdownloadmanager.com`.
- Blok hosts dipasang otomatis pada alur `Normal Activation`, `Freeze Activation`, dan `Reset Activation` sehingga efeknya tetap aktif pada seluruh skenario pemakaian.
- Entri hosts diberi marker unik `# IAS-NADIF-BLOCK` sehingga idempoten: pemanggilan ulang tidak menduplikasi baris. Sebelum menulis ulang, hosts file dicadangkan ke `%SystemRoot%\Temp\_Backup_hosts_<timestamp>` dan cache DNS disegarkan via `ipconfig /flushdns`.
- Domain inti `internetdownloadmanager.com` dibiarkan terbuka agar uji unduhan internal `download_files` tetap berjalan.

### Perubahan
- Pesan UI pada `NORMAL ACTIVATION` diperhalus: peringatan "warning serial palsu" diganti menjadi konfirmasi bahwa warning tersebut sudah diblok via hosts file.
- Pesan akhir `DONE` pada alur normal dan reset menambahkan konfirmasi bypass aktif.

---

## v1.9.5 - 2026-04-21

### Baru
- `Reset_Activation.cmd`: pintasan satu klik untuk menjalankan `IAS.cmd /res`, ditujukan bagi pengguna yang ingin membersihkan status aktivasi atau masa uji coba.
- `Normal_Activation.cmd`: pintasan satu klik untuk menjalankan `IAS.cmd /act`, melengkapi `Quick_Activation.cmd` sebagai tiga jalur masuk utama.
- `.github/ISSUE_TEMPLATE/bug_report.yml`: template laporan bug terstruktur yang mewajibkan informasi versi Windows, versi IDM, dan kode keluar `Test_Script.cmd`, agar proses penelusuran masalah lebih cepat.
- `.github/ISSUE_TEMPLATE/help.yml`: template bantuan penggunaan untuk menurunkan hambatan laporan yang bukan bug, tetapi murni kendala pemakaian.
- `.github/ISSUE_TEMPLATE/config.yml`: menonaktifkan issue kosong dan mengarahkan pengguna agar memeriksa FAQ serta CHANGELOG terlebih dahulu.
- `CHANGELOG.md`: memisahkan catatan perubahan dari README dan release notes agar menjadi satu sumber informasi utama.
- README menambahkan bagian "Unduh Cepat" yang mengarah ke halaman GitHub Releases dan tautan unduhan langsung.
- README menambahkan bagian "Wajib Dibaca Sebelum Menjalankan Pertama Kali" untuk mengingatkan tentang UAC, SmartScreen, dan potensi deteksi antivirus.

### Perubahan
- `Test_Script.cmd`: sekarang menampilkan dengan jelas "pemeriksaan pertama yang gagal" beserta arahan ke bagian README yang relevan. Makna kode keluar tetap sama sehingga otomatisasi tidak perlu diubah.
- `Quick_Activation.cmd`: pemanggilan elevasi PowerShell ditulis ulang menggunakan `-FilePath` dan escape tanda kutip yang lebih ketat, sehingga jalur file dengan tanda petik tunggal atau karakter khusus tidak lagi gagal.
- `Instructions.txt`: disederhanakan menjadi "panduan 3 langkah + penunjuk FAQ", dan peringatan administrator diubah menjadi catatan wajib dibaca.
- `README.md`:
  - menambahkan 4 FAQ baru untuk Win11 24H2, pemblokiran Defender cloud protection, kebijakan WDAC/AppLocker, dan kompatibilitas IDM 6.42+;
  - memperbarui bagian versi dan pemeliharaan ke v1.9.5;
  - menambahkan tiga pintasan satu klik ke tabel penjelasan file;
  - menghapus baris "code page 936" yang membingungkan dari tabel kebutuhan sistem karena skrip sudah mengaturnya otomatis;
  - memindahkan metode baris perintah ke dalam blok `<details>` agar pengguna baru lebih fokus pada metode antarmuka grafis.
- `IAS.cmd`: menambahkan blok komentar "navigasi kode" di bagian kepala skrip agar pemeliharaan berikutnya lebih mudah.

### Perbaikan
- Memperbaiki kegagalan `Quick_Activation.cmd` saat `%~f0` berada pada jalur yang mengandung tanda petik tunggal, yang sebelumnya memicu kesalahan sintaks PowerShell.

### Dokumentasi
- `SECURITY.md` diterjemahkan sepenuhnya ke bahasa yang lebih mudah dipahami, termasuk jalur pelaporan privat, informasi yang perlu disertakan, dan alur penanganan.
- Paket rilis `release/IDM-Activation-Script-v1.9.5.zip` dikemas ulang agar menyertakan dokumentasi terbaru.

### CI
- `.github/workflows/ci.yml` menambahkan langkah smoke test `IAS.cmd /?` pada `windows-latest` untuk memastikan skrip masih dapat merespons bantuan dalam waktu singkat dan mencegah regresi sintaks masuk ke cabang utama.

---

## v1.3 - 2025-12-09

### Baru
- `IAS.cmd` mendukung parameter `/silent` dan `/log=<path>` untuk skenario tanpa interaksi, dengan keluaran log yang dapat dianalisis.
- `Quick_Activation.cmd` ikut meneruskan parameter yang sama.
- `Test_Script.cmd` diperluas menjadi 10 pemeriksaan, dengan kode keluar berbasis bit agar mudah diproses otomatis.

### CI
- Menambahkan GitHub Actions pada Windows runner yang menjalankan `tools/validate.ps1`, untuk memastikan file `.cmd` dan `.txt` tetap memakai GBK serta CRLF, dan untuk memeriksa apakah sintaks `cmd.exe` masih valid.

### Dokumentasi
- Menambahkan penjelasan alur eksekusi dan draf rencana smoke test untuk v1.3.

---

## v1.2 - 2024-10-05

### Baru
- Menambahkan `Quick_Activation.cmd` sebagai pintasan mode beku, `Test_Script.cmd` untuk diagnosis lingkungan, dan `Instructions.txt` sebagai panduan mulai cepat.
- `Test_Script.cmd` menambahkan pemeriksaan layanan Null, mode bahasa PowerShell, dan konektivitas TCP, dengan kode keluar non-zero bila ada kegagalan.

### Perubahan
- Skrip memaksa `chcp 936` saat startup dan setelah `cls`, agar tampilan teks tetap benar di CMD berbahasa Tionghoa.
- Menu utama dan seluruh prompt diterjemahkan, namun tetap mempertahankan tiga mode inti: beku, aktivasi biasa, dan reset.
- Fitur inti seperti pencadangan registri, pemeriksaan jaringan, dan penguncian CLSID tetap dipertahankan.

### Perbaikan
- `Quick_Activation.cmd` kini menampilkan petunjuk elevasi manual bila PowerShell tidak tersedia dan meneruskan kode keluar dari IAS ke pemanggil.
- Seluruh file batch pendukung dan teks bantu diseragamkan encoding-nya ke GBK agar tidak muncul karakter rusak di CMD.

---

## Versi Lebih Lama

Perubahan untuk versi yang lebih lama tersebar di riwayat commit dan tidak lagi dirinci satu per satu. Gunakan `git log --oneline` untuk melihat timeline lengkap.
