import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

const _storage = FlutterSecureStorage();
const _api = 'https://szambo.onrender.com';
const _jwtKey = 'admin_jwt';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const AdminApp());
}

/// ─── główna aplikacja ─────────────────────────────────────────────────────
class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  static final _nav = GlobalKey<NavigatorState>();

  static Future<void> logout() async {
    await _storage.delete(key: _jwtKey);
    _nav.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _nav,
    debugShowCheckedModeBanner: false,
    title: 'TechioT Admin',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
    builder: (context, child) => InactivityWatcher(
      timeout: const Duration(hours: 1),
      onTimeout: logout,
      child: child!,
    ),
    home: const LoginScreen(),
  );
}

/// ─── watcher bezczynności (1 h) ───────────────────────────────────────────
class InactivityWatcher extends StatefulWidget {
  const InactivityWatcher({
    super.key,
    required this.child,
    required this.timeout,
    required this.onTimeout,
  });
  final Widget child;
  final Duration timeout;
  final VoidCallback onTimeout;

  @override
  State<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends State<InactivityWatcher> {
  Timer? _t;
  void _reset() {
    _t?.cancel();
    _t = Timer(widget.timeout, widget.onTimeout);
  }

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext _) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => _reset(),
    child: widget.child,
  );
}

/// ─── ekran logowania ──────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pw = TextEditingController();
  bool _checking = false, _loading = true;
  String? _err;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _autoLogin();
  }

  Future<void> _autoLogin() async {
    if (await _storage.containsKey(key: _jwtKey)) {
      final token = await _storage.read(key: _jwtKey);
      if (token != null) _goToRegister(token);
    }
    setState(() => _loading = false);
  }

  Future<void> _submit() async {
    setState(() {
      _checking = true;
      _err = null;
    });
    try {
      final r = await http.post(
        Uri.parse('$_api/admin/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'password': _pw.text}),
      );
      if (r.statusCode == 200) {
        final token = jsonDecode(r.body)['token'] as String;
        await _storage.write(key: _jwtKey, value: token);
        if (mounted) _goToRegister(token);
      } else {
        setState(() {
          _err = 'Błędne hasło';
          _checking = false;
        });
      }
    } catch (e) {
      setState(() {
        _err = 'Błąd sieci: $e';
        _checking = false;
      });
    }
  }

  void _goToRegister(String jwt) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => RegisterScreen(jwt: jwt)),
    );
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(title: const Text('Logowanie')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _pw,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Hasło',
                    errorText: _err,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _checking ? null : _submit,
                    child: _checking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Zaloguj'),
                  ),
                ),
              ],
            ),
          ),
  );
}

/// ─── ekran rejestracji ────────────────────────────────────────────────────
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.jwt});
  final String jwt;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  bool _sending = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _c = {
      for (final k in [
        'serie_number',
        'email',
        'name',
        'phone',
        'phone2',
        'tel_do_szambiarza',
        'street',
      ])
        k: TextEditingController(),
    };
    _c['serie_number']!.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final v in _c.values) v.dispose();
    super.dispose();
  }

  Future<void> _scanQr() async {
    final code = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const ScanQrScreen()),
    );
    if (code != null) _c['serie_number']!.text = code;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _msg = null;
    });

    final body = {for (final e in _c.entries) e.key: e.value.text.trim()};
    try {
      final r = await http.post(
        Uri.parse('$_api/admin/create-device-with-user'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.jwt}',
        },
        body: jsonEncode(body),
      );

      if (r.statusCode == 200) {
        for (final v in _c.values) v.clear();
        _msg = 'ok';
      } else if (r.statusCode == 207) {
        final obj = jsonDecode(r.body);
        _msg = obj['message'] ?? 'Urządzenia nie znaleziono w LNS';
      } else {
        // 400 / 404 / inne
        try {
          final obj = jsonDecode(r.body);
          _msg =
              obj['message'] ??
              (r.statusCode == 404
                  ? 'Nie znaleziono urządzenia w żadnym z serwerów!'
                  : 'Błąd ${r.statusCode}');
        } catch (_) {
          _msg = r.statusCode == 404
              ? 'Nie znaleziono urządzenia w żadnym z serwerów!'
              : 'Błąd ${r.statusCode}';
        }
      }
    } catch (e) {
      _msg = 'Błąd sieci: $e';
    }
    if (mounted) setState(() => _sending = false);
  }

  Widget _f(
    String lbl,
    String name, {
    TextInputType t = TextInputType.text,
    bool req = false,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextFormField(
      controller: _c[name]!,
      keyboardType: t,
      decoration: InputDecoration(
        labelText: lbl,
        border: const OutlineInputBorder(),
      ),
      validator:
          validator ??
          (req
              ? (v) => (v == null || v.trim().isEmpty) ? 'Wymagane' : null
              : null),
    ),
  );

  @override
  Widget build(BuildContext ctx) {
    final serie = _c['serie_number']!.text;
    final validSerie = RegExp(r'^\d{16}$').hasMatch(serie);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rejestracja urządzenia'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: AdminApp.logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Form(
              key: _form,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _f(
                          'Numer seryjny (EUI)',
                          'serie_number',
                          req: true,
                          validator: (v) {
                            final s = v?.trim() ?? '';
                            if (s.isEmpty) return 'Wymagane';
                            if (!RegExp(r'^\d{16}$').hasMatch(s)) {
                              return 'Musi mieć 16 cyfr';
                            }
                            return null;
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: _scanQr,
                      ),
                    ],
                  ),
                  _f(
                    'Email klienta',
                    'email',
                    t: TextInputType.emailAddress,
                    req: true,
                  ),
                  _f('Imię i nazwisko', 'name'),
                  _f('Telefon', 'phone', t: TextInputType.phone),
                  _f('Telefon 2', 'phone2', t: TextInputType.phone),
                  _f(
                    'Tel. do szambiarza',
                    'tel_do_szambiarza',
                    t: TextInputType.phone,
                  ),
                  _f('Ulica / opis miejsca', 'street'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (serie.isNotEmpty) ...[
              QrImageView(
                data: serie,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 20),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sending || !validSerie ? null : _submit,
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Zarejestruj'),
              ),
            ),
            if (_msg != null) ...[
              const SizedBox(height: 12),
              Text(
                _msg == 'ok' ? '✅ Pomyślnie dodano urządzenie' : _msg!,
                style: TextStyle(
                  color: _msg == 'ok' ? Colors.green : Colors.red,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ─── ScanQrScreen (mobile_scanner) ────────────────────────────────────────
class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});
  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  late final MobileScannerController _ctrl = MobileScannerController(
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.normal,
    formats: [BarcodeFormat.qrCode],
  );

  bool _scanned = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<bool> _perm() async {
    final s = await Permission.camera.status;
    if (s.isGranted) return true;
    return (await Permission.camera.request()).isGranted;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Zeskanuj QR')),
    body: FutureBuilder<bool>(
      future: _perm(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.data!) {
          return const Center(
            child: Text(
              'Brak uprawnień do aparatu',
              style: TextStyle(fontSize: 16, color: Colors.red),
            ),
          );
        }
        return MobileScanner(
          controller: _ctrl,
          onDetect: (capture) {
            if (_scanned) return;
            final val = capture.barcodes.first.rawValue;
            if (val != null) {
              _scanned = true;
              Navigator.of(context).pop(val);
            }
          },
        );
      },
    ),
  );
}
