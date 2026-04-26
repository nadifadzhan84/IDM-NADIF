# Catatan Perubahan

Dokumen ini mencatat semua perubahan yang dirilis untuk IDM Activation Script. Penomoran versi mengikuti gaya [Semantic Versioning](https://semver.org/lang/zh-CN/): `mayor.minor.patch`.

- Format: setiap versi dapat berisi bagian `Baru / Perubahan / Perbaikan / Dokumentasi / Kompatibilitas`, sesuai kebutuhan.
- Tanggal menggunakan zona waktu lokal repositori.
- Versi terbaru selalu ditempatkan di bagian paling atas.

---

## v1.9.13 - 2026-04-26

### Perbaikan
- **Bulletproof: jendela IAS dipastikan tidak menutup sendiri.** v1.9.12 memakai `cmd /k` di dalam `if (...)` block; pengujian menunjukkan jendela masih menutup pada sistem user. Strategi v1.9.13:
  - **Spawn jendela cmd BARU yang fully detached** di akhir flow unattended. Pakai `start "title" cmd /k "echo banner & ..."` yang melahirkan konsol baru dengan conhost sendiri, stdin/stdout sendiri — tidak terpengaruh state stdin parent yang ter-redirect oleh `Start-Process -Verb RunAs` di wrapper. Elevated cmd lama exit sesudahnya, jendela baru tetap menampilkan banner sukses dan menunggu user ketik `exit` atau klik X.
  - Refactor `:done` / `:done2`: keluar dari `if (...)` block via `goto :done_unattended_hold` / `goto :done2_unattended_hold`. Spawn dipanggil di scope top-level, bukan di dalam parens.
  - **Fallback bulletproof: loop `ping 127.0.0.1 -n 60`** yang berjalan kalau `start` gagal (rare). Loop ini tidak bergantung pada stdin sama sekali — jendela elevated lama akan tetap terbuka sampai user klik X.
  - Banner sukses jendela baru: `AKTIVASI IDM SELESAI - tutup jendela ini dengan ketik exit lalu Enter, atau klik X di pojok kanan` dengan latar hijau (`color 2F`) supaya jelas terlihat.

### Kompatibilitas
- Mode `/silent` tetap auto-exit tanpa hold (perilaku otomasi tidak berubah).
- Mode interaktif (menu IAS.cmd tanpa argumen) tetap memakai `pause` / `choice` standar.

---

## v1.9.12 - 2026-04-26

### Perbaikan
- **Konsol IAS dijamin tidak menutup sendiri setelah aktivasi sukses.** Iterasi v1.9.11 mengganti `timeout /t 2 & exit /b` dengan `pause >nul <con`, mengasumsikan redirect `<con` cukup membuka device console asli. Ternyata pada beberapa konfigurasi UAC / `Start-Process -Verb RunAs`, handle yang dibuka oleh `<con` mewarisi state yang sama dengan stdin parent yang sudah ter-redirect, sehingga `pause` tetap exit instan dan jendela menutup. v1.9.12 mengganti pendekatannya:
  - `:done` dan `:done2` di `IAS.cmd` melahirkan shell baru via `cmd /k` setelah aktivasi selesai. Shell baru itu memperoleh handle console fresh dari conhost dan tidak akan exit otomatis — user wajib mengetik `exit` lalu Enter, atau menutup jendela manual (klik X). Dijamin tidak close sendiri terlepas dari kondisi stdin parent.
  - Banner sukses `AKTIVASI SELESAI` + petunjuk `Ketik exit lalu tekan Enter untuk menutup, atau klik X di pojok kanan` tetap ditampilkan sebelum `cmd /k`.
  - `Normal_Activation.cmd` / `Quick_Activation.cmd` / `Reset_Activation.cmd` menghapus `pause` di happy-path (sudah ditahan oleh `cmd /k` di IAS.cmd) dan hanya pause kalau IAS.cmd return error code != 0 supaya pesan error sempat dilihat.

### Kompatibilitas
- Mode `/silent` tetap auto-exit tanpa banner / `cmd /k` (perilaku CI / otomatisasi tidak berubah).
- Mode interaktif (jalankan `IAS.cmd` tanpa argumen) tetap memakai prompt `Tekan 0` / `Tekan sembarang tombol` standar, kembali ke MainMenu.

---

## v1.9.11 - 2026-04-26

### Perbaikan
- **Konsol IAS tidak lagi menutup sendiri SETELAH aktivasi sukses.** Pada `Normal_Activation.cmd` / `Quick_Activation.cmd` / `Reset_Activation.cmd`, langkah elevasi `powershell ... Start-Process -Verb RunAs` melahirkan cmd dengan stdin yang sudah ter-redirect (bukan handle CON yang sebenarnya). Akibatnya `timeout /t 2` di label `:done` IAS.cmd dan `pause` di wrapper exit instan dengan `"Input redirection is not supported"` — jendela tertutup walau aktivasi sudah berhasil dan IDM sudah teregister.
  - `:done` dan `:done2` di `IAS.cmd` mengganti `timeout /t 2 & exit /b` dengan banner sukses + `pause >nul <con`. Redirect `<con` membaca langsung dari device console asli sehingga pause selalu menunggu keypress nyata, tidak terpengaruh stdin yang ter-redirect.
  - `Normal_Activation.cmd`, `Quick_Activation.cmd`, dan `Reset_Activation.cmd` mengganti `pause` di akhir flow dengan `pause <con` dengan alasan yang sama.

### Kompatibilitas
- Mode `/silent` tetap auto-exit tanpa pause (perilaku tidak berubah).
- Mode interaktif (menjalankan `IAS.cmd` tanpa flag) tetap memakai `pause` dan `choice` standar — perilaku tidak berubah.

---

## v1.9.10 - 2026-04-26

### Perbaikan
- **Konsol IAS tidak lagi tertutup sendiri di tengah Normal Activation.** Sebelumnya `:install_popup_watcher` menjalankan `start "" /b powershell ... -File "%pw_ps%"` yang menempelkan PowerShell `popup_watcher.ps1` ke konsol IAS yang sama (shared stdin/stdout). Akibatnya pada beberapa sistem `timeout /t 1` di alur `:download_files` mencetak *"Input redirection is not supported, exiting the process immediately"* dan/atau membuat konsol tertutup ketika IDM atau watcher mengambil fokus / handle stdin. Sekarang watcher dilahirkan via `schtasks /run /tn "IAS-NADIF-PopupWatcher"` (pola yang sama dengan `:install_trial_resetter`) sehingga PowerShell berjalan di sesi user terpisah, tidak berbagi konsol dengan IAS. Fallback `start /b ... <nul %nul%` tetap ada andai `schtasks /run` gagal.
- `:check_file` mengganti `timeout /t 1 %nul1%` dengan `ping 127.0.0.1 -n 2 %nul1%` agar polling unduhan IDM tidak ter-skip ke loop ketat ketika `timeout` menolak stdin yang sudah di-redirect / dikonsumsi proses anak.

### Perubahan
- **Popup "0 days left to use Internet Download Manager" yang muncul ~1 hari setelah Normal Activation kini ditekan secara real-time.** `tools_nadif\popup_watcher.ps1` dilengkapi fungsi `Reset-TrialCounters` yang dipanggil di hot loop tiap ~750 ms. Fungsi ini menghapus `tvfrdt`, `radxcnt`, `ptrk_scdt`, `LstCheck`, `LastCheckQU`, `scansk`, `FromVersion`, dan `toV` dari `HKCU\Software\DownloadManager` setiap iterasi sehingga IDM 6.42 tidak punya jendela waktu untuk meng-advance counter trial ke 0. Serial / FName / LName / Email tetap **tidak pernah** disentuh.
- Scheduled Task `IAS-NADIF-TrialResetter` diubah dari `/sc hourly /mo 1` menjadi `/sc minute /mo 5`. Hourly sebelumnya terlalu jarang ketika watcher belum sempat berjalan (mis. user logout di tengah aktivasi). Resetter sekarang menjadi lapisan kedua di belakang inline-reset di watcher.
- `popup_watcher.ps1` `Triggers` diperluas dari 5 menjadi 9 frasa sehingga dialog *"You have 0 days left"* / *"You may buy IDM to continue using it"* / *"PLEASE ENTER YOUR SERIAL NUMBER"* / *"ALREADY PURCHASED"* ikut ditutup. Frasa `Lifetime license` sengaja **tidak** dimasukkan karena dialog informasi benign *"This product is licensed to ... This is a lifetime license"* memuat teks itu dan tidak boleh ditutup paksa.

### Kompatibilitas
- Fallback `start "" /b powershell ... <nul %nul%` di `:install_popup_watcher` tetap kompatibel dengan Windows 7 (yang `schtasks /run`-nya kadang gagal di lingkungan service-pack lama).
- `Reset-TrialCounters` memanggil `Get-ItemProperty -ErrorAction Stop` lalu `Remove-ItemProperty` di blok try/catch supaya nilai yang sudah tidak ada tidak menimbulkan log spam.
- Jadwal 5 menit memakai `/sc minute /mo 5` di Windows 7+ — sintaks yang didukung sejak XP.

### Verifikasi CI
- `.github/workflows/windows-smoke.yml` job `popup-watcher` diperluas: memastikan 9 frasa pemicu hadir, memastikan `Reset-TrialCounters` ada, dan menambahkan guard yang melarang `Lifetime license` masuk ke daftar `Triggers`. Job `trial-resetter` menambah probe untuk skedul `/sc minute /mo 5`.

---

## v1.9.9 - 2026-04-26

### Baru
- `tools_nadif/trial_reset.ps1`: script resetter trial-counter IDM. Menghapus `tvfrdt`, `radxcnt`, `ptrk_scdt`, `LstCheck`, `LastCheckQU`, `scansk`, `FromVersion`, `toV` dari `HKCU\Software\DownloadManager` sehingga IDM tidak dapat meng-advance counter trial ke 0. **Serial, FName, LName, dan Email tidak pernah disentuh** agar registri IDM tetap "registered". Log di `%LOCALAPPDATA%\IAS-NADIF\trial_reset.log`.
- `IAS.cmd`: subrutin baru `:install_trial_resetter` dan `:uninstall_trial_resetter`. Resetter didaftarkan sebagai Scheduled Task `IAS-NADIF-TrialResetter` dengan trigger hourly (`/sc hourly /mo 1`) di konteks user (`rl limited`, `WindowStyle Hidden`). Task juga langsung dijalankan sekali via `schtasks /run` agar counter trial yang lama langsung bersih di sesi aktivasi.
- Hook baru pada `:_activate` alur **Normal** (baris 702): setelah `:install_popup_watcher`, `:install_trial_resetter` dipanggil supaya popup *"You have N days left to use Internet Download Manager"* maupun hard-stop *"0 days left"* tidak pernah terpicu.
- Hook baru pada `:_reset` sebagai `STEP 07 Mencopot resetter trial IDM`.
- `popup_watcher.ps1`: tabel `Triggers` diperluas dari 2 pola (*fake Serial* / *Serial Number has been blocked*) menjadi 5 pola. Tambahan:
  - `days left to use Internet Download Manager`
  - `trial period has expired`
  - `trial version has expired`
  Jadi watcher kini menutup baik popup fake-serial maupun popup trial-expired jika sempat muncul sebelum resetter sempat menghapus counter.
- `Test_Script.cmd`: probe informatif baru untuk Scheduled Task `IAS-NADIF-TrialResetter`. Tetap tidak menaikkan kode keluar (informatif saja).
- `.github/workflows/windows-smoke.yml`: job baru `trial-resetter`. Memverifikasi tokenisasi PS1, memastikan scope hanya menyentuh nilai trial-counter yang diizinkan, dan melarang pola `Remove-ItemProperty -Name Serial/FName/LName/Email` (safety guard supaya tidak pernah tidak sengaja meng-unregister IDM). Job `popup-watcher` diperluas untuk menegaskan 5 frasa pemicu baru hadir di script.

### Perubahan
- Alur Normal Activation sekarang memasang **dua** Scheduled Task pelengkap:
  - `IAS-NADIF-PopupWatcher` (onlogon) - menutup popup nag IDM
  - `IAS-NADIF-TrialResetter` (hourly) - mencegah counter trial sampai 0
- Alur Reset mencopot kedua task tersebut.

### Kompatibilitas
- `trial_reset.ps1` memanggil `Remove-ItemProperty` dengan `-ErrorAction SilentlyContinue` untuk nilai yang tidak ada, sehingga aman dijalankan berulang pada registri yang sudah bersih.
- Watcher tetap memfilter pada kelas window `#32770` + judul persis `Internet Download Manager`. Penambahan 3 frasa trial-expiry tidak melonggarkan filter kelas/judul, sehingga dialog "lifetime license" yang benign tetap tidak tersentuh.

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
