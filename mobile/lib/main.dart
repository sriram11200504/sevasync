import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:geolocator/geolocator.dart';

// ─── Config ────────────────────────────────────────────────────────────────
const String kApiBase = 'https://sevasync-backend-h2gh.onrender.com/api';



// ─── App Root ───────────────────────────────────────────────────────────────
void main() => runApp(const SevaSyncApp());

class SevaSyncApp extends StatelessWidget {
  const SevaSyncApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SevaSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080D17),
        colorScheme: ColorScheme.dark(primary: const Color(0xFF3B82F6)),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const RoleSelectionScreen(),
    );
  }
}

// ─── Colours ────────────────────────────────────────────────────────────────
const kSurface   = Color(0xFF0E1726);
const kSurface2  = Color(0xFF131F33);
const kBorder    = Color(0x12FFFFFF);
const kGreen     = Color(0xFF10B981);
const kOrange    = Color(0xFFF59E0B);
const kRed       = Color(0xFFEF4444);
const kAccent    = Color(0xFF3B82F6);
const kMuted     = Color(0xFF4A5568);

Map<String, Color> kNeedColors = {
  'food': kOrange, 'medical': kRed,
  'shelter': const Color(0xFF8B5CF6), 'water': const Color(0xFF06B6D4), 'other': kMuted,
};

// ─── Helpers ────────────────────────────────────────────────────────────────
Future<http.Response?> safePost(String path, Map body) async {
  try {
    return await http.post(Uri.parse('$kApiBase$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body));
  } catch (_) { return null; }
}

Future<http.Response?> safePut(String path, Map body) async {
  try {
    return await http.put(Uri.parse('$kApiBase$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body));
  } catch (_) { return null; }
}

Future<List<dynamic>> fetchRequests() async {
  try {
    final r = await http.get(Uri.parse('$kApiBase/requests'));
    if (r.statusCode == 200) return jsonDecode(r.body)['data'];
  } catch (_) {}
  return [];
}

// ─── Role Selection Screen ───────────────────────────────────────────────────
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  Widget _roleCard(BuildContext ctx, {
    required IconData icon, required String title,
    required String subtitle, required Color color, required Widget dest,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => dest)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.35)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: kMuted)),
          ])),
          Icon(Icons.chevron_right, color: color, size: 22),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(center: const Alignment(-0.5, -0.6), radius: 1.5,
            colors: [const Color(0xFF0E1726), const Color(0xFF080D17)]),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 24),
              Row(children: [
                Container(
                  width: 8, height: 8, decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(colors: [Color(0xFF60A5FA), Color(0xFFA78BFA)]).createShader(bounds),
                  child: const Text('SevaSync', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ]),
              const SizedBox(height: 4),
              const Text('Ground Operations Platform', style: TextStyle(color: kMuted, fontSize: 13, letterSpacing: 1)),
              const SizedBox(height: 48),
              const Text('Who are you?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text('Select your role to continue', style: TextStyle(color: kMuted, fontSize: 14)),
              const SizedBox(height: 32),
              _roleCard(context,
                icon: Icons.personal_injury_outlined,
                title: 'I Need Help',
                subtitle: 'Public / Beneficiary · Submit emergency request',
                color: kRed, dest: const BeneficiaryFlow()),
              _roleCard(context,
                icon: Icons.volunteer_activism,
                title: 'I am a Volunteer',
                subtitle: 'View and complete assigned missions',
                color: kGreen, dest: const VolunteerFlow()),
              _roleCard(context,
                icon: Icons.assignment_outlined,
                title: 'NGO Field Worker',
                subtitle: 'Upload survey data and reports from the field',
                color: kAccent, dest: const NgoFieldFlow()),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Beneficiary Flow ────────────────────────────────────────────────────────
class BeneficiaryFlow extends StatefulWidget {
  const BeneficiaryFlow({super.key});
  @override State<BeneficiaryFlow> createState() => _BeneficiaryFlowState();
}

enum _BenefInputMode { text, voice, camera }

class _BeneficiaryFlowState extends State<BeneficiaryFlow> {
  final List<Map> _requests = [];
  bool _loading = false;

  // Text
  final _textCtrl = TextEditingController();

  // Voice
  final SpeechToText _speech = SpeechToText();
  bool _speechReady = false;
  bool _listening = false;
  String _voiceText = '';
  String _selectedLocale = 'en_IN';  // default English (India)
  final List<Map<String, String>> _languages = [
    {'code': 'en_IN', 'label': '🇬🇧 English'},
    {'code': 'hi_IN', 'label': '🇮🇳 हिंदी'},
    {'code': 'te_IN', 'label': '🇮🇳 తెలుగు'},
    {'code': 'ta_IN', 'label': '🇮🇳 தமிழ்'},
    {'code': 'kn_IN', 'label': '🇮🇳 ಕನ್ನಡ'},
    {'code': 'ml_IN', 'label': '🇮🇳 മലയാളം'},
    {'code': 'mr_IN', 'label': '🇮🇳 मराठी'},
    {'code': 'bn_IN', 'label': '🇮🇳 বাংলা'},
    {'code': 'gu_IN', 'label': '🇮🇳 ગુજરાતી'},
    {'code': 'ur_IN', 'label': '🇮🇳 اردو'},
  ];

  @override
  void initState() {
    super.initState();
    _speech.initialize(
      onError: (_) => setState(() => _listening = false),
      onStatus: (s) { if (s == 'done' || s == 'notListening') setState(() => _listening = false); },
    ).then((ok) => setState(() => _speechReady = ok));
  }

  @override
  void dispose() { _textCtrl.dispose(); super.dispose(); }

  void _showInputPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: kMuted.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('How do you want to report?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Choose the easiest way for you', style: TextStyle(color: kMuted, fontSize: 13)),
          const SizedBox(height: 20),
          _pickOption(Icons.edit_note, 'Type your problem', 'Write what help you need in any language', kRed, () { Navigator.pop(context); _openInputSheet(_BenefInputMode.text); }),
          _pickOption(Icons.mic, 'Speak in your language', 'Just talk — works in Hindi, Telugu, Tamil & more', kOrange, () { Navigator.pop(context); _openInputSheet(_BenefInputMode.voice); }),
          _pickOption(Icons.camera_alt, 'Take a Photo', 'Camera captures scene + auto-detects your GPS location', const Color(0xFF8B5CF6), () { Navigator.pop(context); _openInputSheet(_BenefInputMode.camera); }),
        ]),
      ),
    );
  }

  Widget _pickOption(IconData icon, String title, String sub, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.2))),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(color: kMuted, fontSize: 12.5)),
          ])),
          Icon(Icons.chevron_right, color: color, size: 20),
        ]),
      ),
    );
  }

  void _openInputSheet(_BenefInputMode mode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        if (mode == _BenefInputMode.text)   return _textSheet(ctx);
        if (mode == _BenefInputMode.voice)  return _voiceSheet(ctx);
        return _cameraSheet(ctx);
      },
    );
  }

  void _addResult(Map data) {
    setState(() => _requests.insert(0, data));
  }

  // ── TEXT INPUT SHEET ─────────────────────────────────────────────────────
  Widget _textSheet(BuildContext ctx) {
    return StatefulBuilder(builder: (ctx, setSheetState) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 28),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kMuted.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          const Text('📝 Describe your emergency', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kRed)),
          const SizedBox(height: 6),
          const Text('Write in any language — AI will understand', style: TextStyle(color: kMuted, fontSize: 13)),
          const SizedBox(height: 18),
          _textField(_textCtrl, 'e.g. हमें पार्क स्ट्रीट पर तुरंत खाना चाहिए, 30 परिवार...', maxLines: 5),
          const SizedBox(height: 14),
          _primaryButton(label: 'Send Help Request', color: kRed, loading: _loading, onTap: () async {
            if (_textCtrl.text.trim().isEmpty) return;
            setSheetState(() {}); setState(() => _loading = true);
            final res = await safePost('/ingest', {'text': _textCtrl.text.trim(), 'source': 'public', 'translate': true});
            setState(() => _loading = false);
            if (res != null && res.statusCode == 200) {
              final data = Map.from(jsonDecode(res.body)['data']); data['input_type'] = 'text';
              _textCtrl.clear();
              Navigator.pop(ctx);
              _addResult(data);
            } else { _snack(ctx, 'Failed. Check backend.', isError: true); }
          }),
        ])),
      );
    });
  }

  // ── VOICE INPUT SHEET ───────────────────────────────────────────────────
  Widget _voiceSheet(BuildContext ctx) {
    return StatefulBuilder(builder: (ctx, setSheetState) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 28),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kMuted.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          const Text('🎙️ Speak your emergency', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kOrange)),
          const SizedBox(height: 6),
          const Text('Choose your language, then tap the mic', style: TextStyle(color: kMuted, fontSize: 13)),
          const SizedBox(height: 16),

          // Language selector
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _languages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final lang = _languages[i];
                final selected = lang['code'] == _selectedLocale;
                return GestureDetector(
                  onTap: () { setSheetState(() => _selectedLocale = lang['code']!); setState(() {}); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? kOrange.withOpacity(0.15) : kSurface2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? kOrange : kBorder),
                    ),
                    child: Text(lang['label']!, style: TextStyle(fontSize: 13, color: selected ? kOrange : kMuted, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Mic button
          Center(child: GestureDetector(
            onTap: _loading ? null : () async {
              if (!_speechReady) { _snack(ctx, 'Mic not available', isError: true); return; }
              if (_listening) {
                _speech.stop();
                setSheetState(() {}); setState(() => _listening = false);
              } else {
                setSheetState(() {}); setState(() { _voiceText = ''; _listening = true; });
                await _speech.listen(
                  onResult: (r) { setSheetState(() {}); setState(() => _voiceText = r.recognizedWords); },
                  localeId: _selectedLocale,
                  listenFor: const Duration(seconds: 30),
                  pauseFor: const Duration(seconds: 4),
                );
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 96, height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _listening ? kOrange.withOpacity(0.12) : kSurface2,
                border: Border.all(color: _listening ? kOrange : kMuted.withOpacity(0.3), width: _listening ? 3 : 1),
                boxShadow: _listening ? [BoxShadow(color: kOrange.withOpacity(0.3), blurRadius: 24, spreadRadius: 4)] : [],
              ),
              child: Icon(_listening ? Icons.stop : Icons.mic, color: _listening ? kOrange : kMuted, size: 40),
            ),
          )),
          const SizedBox(height: 10),
          Center(child: Text(_listening ? 'Listening... tap to stop' : 'Tap mic to speak', style: TextStyle(color: _listening ? kOrange : kMuted, fontSize: 13))),

          if (_voiceText.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('Transcript', style: TextStyle(color: kMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: kOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(_languages.firstWhere((l) => l['code'] == _selectedLocale)['label']!, style: const TextStyle(fontSize: 11, color: kOrange)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(_voiceText, style: const TextStyle(fontSize: 14.5, height: 1.5)),
              ]),
            ),
            const SizedBox(height: 6),
            const Text('AI will auto-translate to English before processing', style: TextStyle(color: kMuted, fontSize: 11.5, fontStyle: FontStyle.italic)),
            const SizedBox(height: 14),
            _primaryButton(
              label: 'Submit Help Request',
              color: kOrange, loading: _loading,
              onTap: () async {
                if (_voiceText.trim().isEmpty) return;
                setSheetState(() {}); setState(() => _loading = true);
                final langLabel = _languages.firstWhere((l) => l['code'] == _selectedLocale)['label']!;
                final res = await safePost('/ingest', {
                  'text': _voiceText.trim(),
                  'source': 'public',
                  'original_language': langLabel,
                  'translate': true,
                });
                setState(() => _loading = false);
                if (res != null && res.statusCode == 200) {
                  final data = Map.from(jsonDecode(res.body)['data']); data['input_type'] = 'voice';
                  Navigator.pop(ctx);
                  _addResult(data);
                  setSheetState(() {}); setState(() => _voiceText = '');
                } else { _snack(ctx, 'Submission failed', isError: true); }
              },
            ),
          ],
        ])),
      );
    });
  }

  // ── CAMERA INPUT SHEET ──────────────────────────────────────────────────
  Widget _cameraSheet(BuildContext ctx) {
    return StatefulBuilder(builder: (ctx, setSheetState) {
      String? status;
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 28),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kMuted.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          const Text('📸 Photo Report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6))),
          const SizedBox(height: 6),
          const Text('Take a live photo — GPS location is auto-captured', style: TextStyle(color: kMuted, fontSize: 13)),
          const SizedBox(height: 20),

          // Camera button
          GestureDetector(
            onTap: _loading ? null : () async {
              final picker = ImagePicker();
              final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
              if (file == null) return;

              setSheetState(() => status = 'Getting GPS location...');
              setState(() => _loading = true);

              // Get GPS coordinates
              double? lat, lng;
              try {
                bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                if (serviceEnabled) {
                  LocationPermission perm = await Geolocator.checkPermission();
                  if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
                  if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
                    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).timeout(const Duration(seconds: 8));
                    lat = pos.latitude; lng = pos.longitude;
                  }
                }
              } catch (_) {}

              setSheetState(() => status = 'Uploading to Gemini Vision...');

              try {
                final bytes = await file.readAsBytes();
                final req = http.MultipartRequest('POST', Uri.parse('$kApiBase/upload/image'));
                req.files.add(http.MultipartFile.fromBytes('image', bytes, filename: file.name));
                req.fields['source'] = 'public';
                if (lat != null && lng != null) {
                  req.fields['lat'] = lat.toString();
                  req.fields['lng'] = lng.toString();
                }
                final stream = await req.send();
                final res = await http.Response.fromStream(stream);
                if (res.statusCode == 200) {
                  final data = Map.from(jsonDecode(res.body)['data']);
                  data['input_type'] = 'camera';
                  if (lat != null) data['coordinates'] = {'lat': lat, 'lng': lng};
                  Navigator.pop(ctx);
                  _addResult(data);
                } else {
                  _snack(ctx, 'Image analysis failed', isError: true);
                }
              } catch (e) {
                _snack(ctx, 'Upload error: $e', isError: true);
              }
              setState(() => _loading = false);
            },
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.35)),
              ),
              child: _loading
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const CircularProgressIndicator(color: Color(0xFF8B5CF6), strokeWidth: 2),
                      const SizedBox(height: 14),
                      Text(status ?? 'Processing...', style: const TextStyle(color: kMuted, fontSize: 13)),
                    ])
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.camera_alt, size: 44, color: const Color(0xFF8B5CF6).withOpacity(0.6)),
                      const SizedBox(height: 10),
                      const Text('Tap to Open Camera', style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 4),
                      const Text('GPS coordinates auto-tagged on photo', style: TextStyle(color: kMuted, fontSize: 12)),
                    ]),
            ),
          ),
          const SizedBox(height: 14),

          // Gallery fallback
          GestureDetector(
            onTap: _loading ? null : () async {
              final picker = ImagePicker();
              final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
              if (file == null) return;

              setState(() => _loading = true);
              setSheetState(() => status = 'Uploading to Gemini Vision...');

              try {
                final bytes = await file.readAsBytes();
                final req = http.MultipartRequest('POST', Uri.parse('$kApiBase/upload/image'));
                req.files.add(http.MultipartFile.fromBytes('image', bytes, filename: file.name));
                req.fields['source'] = 'public';
                final stream = await req.send();
                final res = await http.Response.fromStream(stream);
                if (res.statusCode == 200) {
                  final data = Map.from(jsonDecode(res.body)['data']); data['input_type'] = 'image';
                  Navigator.pop(ctx);
                  _addResult(data);
                } else { _snack(ctx, 'Image analysis failed', isError: true); }
              } catch (e) { _snack(ctx, 'Upload error: $e', isError: true); }
              setState(() => _loading = false);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: kSurface2, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.photo_library_outlined, size: 18, color: kMuted),
                SizedBox(width: 8),
                Text('Or choose from Gallery', style: TextStyle(color: kMuted, fontSize: 13)),
              ]),
            ),
          ),
        ])),
      );
    });
  }

  // ── MAIN BUILD ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Request Help', style: TextStyle(fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: kRed.withOpacity(0.6)),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showInputPicker,
        backgroundColor: kRed,
        icon: const Icon(Icons.sos_outlined, color: Colors.white),
        label: const Text('Ask for Help', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _requests.isEmpty
          ? _emptyBenefState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _requests.length,
              itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _requestCard(_requests[i])),
            ),
    );
  }

  Widget _emptyBenefState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: kRed.withOpacity(0.08), shape: BoxShape.circle, border: Border.all(color: kRed.withOpacity(0.25))),
            child: const Icon(Icons.emergency_outlined, size: 36, color: kRed),
          ),
          const SizedBox(height: 20),
          const Text('Need help?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Tap the button below to request assistance. You can type, speak in your own language, or take a photo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kMuted, fontSize: 13.5, height: 1.6),
          ),
          const SizedBox(height: 28),
          Wrap(spacing: 10, runSpacing: 8, alignment: WrapAlignment.center, children: [
            _fmtChip(Icons.edit_note, 'Type', kRed),
            _fmtChip(Icons.mic, 'Speak', kOrange),
            _fmtChip(Icons.camera_alt, 'Photo', const Color(0xFF8B5CF6)),
          ]),
          const SizedBox(height: 12),
          const Text('10+ Indian languages supported', style: TextStyle(color: kMuted, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _fmtChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.25))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _requestCard(Map r) {
    final color = kNeedColors[r['need_type']] ?? kMuted;
    final inputType = r['input_type'] as String? ?? 'text';
    final inputIcon = {'voice': Icons.mic, 'camera': Icons.camera_alt, 'image': Icons.photo}[inputType] ?? Icons.text_fields;
    final coords = r['coordinates'] as Map?;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface, borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(inputIcon, size: 13, color: kMuted),
          const SizedBox(width: 5),
          Text(inputType.toUpperCase(), style: const TextStyle(fontSize: 10, color: kMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          if (coords != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.gps_fixed, size: 11, color: kGreen),
            const SizedBox(width: 3),
            Text('GPS', style: TextStyle(fontSize: 9, color: kGreen, fontWeight: FontWeight.w700)),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(5)),
            child: Text((r['need_type'] ?? 'other').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(width: 8),
          _urgBadge(r['urgency'] ?? 'medium'),
        ]),
        const SizedBox(height: 8),
        Text('📍 ${r['location'] ?? 'Not Specified'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        if (coords != null) Text('   ${coords['lat']?.toStringAsFixed(4)}, ${coords['lng']?.toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: kMuted)),
        const SizedBox(height: 3),
        Text(r['description'] ?? '', style: const TextStyle(fontSize: 12.5, color: kMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Row(children: [
          Text('👥 ${r['people_count'] ?? '?'} people', style: const TextStyle(fontSize: 12, color: kMuted)),
          const Spacer(),
          const Icon(Icons.check_circle, size: 13, color: kGreen),
          const SizedBox(width: 4),
          const Text('Help request sent', style: TextStyle(fontSize: 11, color: kGreen)),
        ]),
      ]),
    );
  }
}


// ─── Volunteer Flow ──────────────────────────────────────────────────────────
class VolunteerFlow extends StatefulWidget {
  const VolunteerFlow({super.key});
  @override State<VolunteerFlow> createState() => _VolunteerFlowState();
}

class _VolunteerFlowState extends State<VolunteerFlow> {
  List _tasks = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await fetchRequests();
    setState(() {
      // Show tasks that are allocated or in-progress
      _tasks = all.where((t) => t['status'] == 'allocated' || t['status'] == 'in-progress').toList();
      _loading = false;
    });
  }

  Future<void> _updateStatus(String id, String status) async {
    final res = await safePut('/requests/$id/status', {'status': status});
    if (res != null && res.statusCode == 200) _load();
    else _showSnack('Update failed', isError: true);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg),
      backgroundColor: isError ? kRed : kGreen));
  }

  Color _needColor(String t) => kNeedColors[t] ?? kMuted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar('My Missions', kGreen),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : RefreshIndicator(
              onRefresh: _load, color: kGreen,
              child: _tasks.isEmpty
                  ? _emptyState(icon: Icons.check_circle_outline, msg: 'No active missions assigned', color: kGreen)
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _tasks.length,
                      itemBuilder: (_, i) {
                        final t = _tasks[i];
                        final isStarted = t['status'] == 'in-progress';
                        final color = _needColor(t['need_type'] ?? 'other');
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: kSurface, borderRadius: BorderRadius.circular(16),
                            border: Border(left: BorderSide(color: color, width: 4)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                  child: Text((t['need_type'] ?? 'other').toUpperCase(),
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                                ),
                                const SizedBox(width: 8),
                                _urgBadge(t['urgency'] ?? 'medium'),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (isStarted ? kOrange : kAccent).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(isStarted ? 'IN PROGRESS' : 'ASSIGNED',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isStarted ? kOrange : kAccent)),
                                ),
                              ]),
                              const SizedBox(height: 10),
                              Text('📍 ${t['location'] ?? 'Unknown'}',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(t['description'] ?? '', style: const TextStyle(fontSize: 13, color: kMuted)),
                              const SizedBox(height: 14),
                              Row(children: [
                                Text('👥 ${t['people_count'] ?? '?'} people', style: const TextStyle(fontSize: 12, color: kMuted)),
                                const Spacer(),
                                if (!isStarted)
                                  Row(children: [
                                    _ghostBtn('Decline', kRed, () => _updateStatus(t['id'], 'declined')),
                                    const SizedBox(width: 8),
                                    _solidBtn('Accept', kGreen, () => _updateStatus(t['id'], 'in-progress')),
                                  ])
                                else
                                  _solidBtn('Mark Complete ✓', kGreen, () => _updateStatus(t['id'], 'completed')),
                              ]),
                            ]),
                          ),
                        );
                      }),
            ),
    );
  }
}

// ─── NGO Field Worker Flow ───────────────────────────────────────────────────
class NgoFieldFlow extends StatefulWidget {
  const NgoFieldFlow({super.key});
  @override State<NgoFieldFlow> createState() => _NgoFieldFlowState();
}

enum _InputMode { text, image, excel, voice, pdf }

class _NgoFieldFlowState extends State<NgoFieldFlow> {
  final List<Map> _submitted = [];
  bool _loading = false;

  // Controllers / state for each mode
  final _textCtrl = TextEditingController();
  bool _listening = false;
  String _voiceTranscript = '';
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _speech.initialize(
      onError: (_) => setState(() => _listening = false),
      onStatus: (s) { if (s == 'done' || s == 'notListening') setState(() => _listening = false); },
    ).then((ok) => setState(() => _speechAvailable = ok));
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _showFormatPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FormatPickerSheet(onSelected: (mode) {
        Navigator.pop(context);
        _openInputSheet(mode);
      }),
    );
  }

  void _openInputSheet(_InputMode mode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _InputSheet(
        mode: mode,
        textCtrl: _textCtrl,
        speech: _speech,
        speechAvailable: _speechAvailable,
        loading: _loading,
        voiceTranscript: _voiceTranscript,
        onTranscriptChange: (t) => setState(() => _voiceTranscript = t),
        onListeningChange: (b) => setState(() => _listening = b),
        listening: _listening,
        onSubmitResult: (result) {
          Navigator.pop(ctx);
          setState(() => _submitted.insert(0, result));
        },
        onBatchResults: (results) {
          Navigator.pop(ctx);
          setState(() => _submitted.insertAll(0, results));
        },
        setLoading: (b) => setState(() => _loading = b),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('NGO Field Reports', style: TextStyle(fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: kAccent.withOpacity(0.6)),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showFormatPicker,
        backgroundColor: kAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _submitted.isEmpty
          ? _emptyNgoState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _submitted.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _submittedCard(_submitted[i]),
              ),
            ),
    );
  }

  Widget _emptyNgoState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: kAccent.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(color: kAccent.withOpacity(0.25)),
            ),
            child: const Icon(Icons.upload_file_outlined, size: 36, color: kAccent),
          ),
          const SizedBox(height: 20),
          const Text('No reports yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            'Tap + New Report to submit a field report in any format — text, image, document, Excel sheet or voice.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kMuted, fontSize: 13.5, height: 1.6),
          ),
          const SizedBox(height: 32),
          Wrap(spacing: 10, runSpacing: 8, alignment: WrapAlignment.center, children: [
            _formatChip(Icons.text_fields, 'Text Report', kAccent),
            _formatChip(Icons.camera_alt, 'Photo / Image', const Color(0xFF8B5CF6)),
            _formatChip(Icons.picture_as_pdf, 'PDF / Doc', kRed),
            _formatChip(Icons.table_chart, 'Excel / CSV', kGreen),
            _formatChip(Icons.mic, 'Voice Note', kOrange),
          ]),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Widget _formatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _submittedCard(Map r) {
    final color = kNeedColors[r['need_type']] ?? kMuted;
    final inputType = r['input_type'] as String? ?? 'text';
    final inputIcon = {'image': Icons.camera_alt, 'excel': Icons.table_chart, 'voice': Icons.mic, 'pdf': Icons.picture_as_pdf}[inputType] ?? Icons.text_fields;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(inputIcon, size: 13, color: kMuted),
          const SizedBox(width: 5),
          Text(inputType.toUpperCase(), style: const TextStyle(fontSize: 10, color: kMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(5)),
            child: Text((r['need_type'] ?? 'other').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(width: 8),
          _urgBadge(r['urgency'] ?? 'medium'),
        ]),
        const SizedBox(height: 8),
        Text('📍 ${r['location'] ?? 'Not Specified'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(r['description'] ?? '', style: const TextStyle(fontSize: 12.5, color: kMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Row(children: [
          Text('👥 ${r['people_count'] ?? '?'} people', style: const TextStyle(fontSize: 12, color: kMuted)),
          const Spacer(),
          const Icon(Icons.check_circle, size: 13, color: kGreen),
          const SizedBox(width: 4),
          const Text('Logged to Control Center', style: TextStyle(fontSize: 11, color: kGreen)),
        ]),
      ]),
    );
  }
}

// ─── Format Picker Bottom Sheet ──────────────────────────────────────────────
class _FormatPickerSheet extends StatelessWidget {
  final void Function(_InputMode) onSelected;
  const _FormatPickerSheet({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final formats = [
      (_InputMode.text,  Icons.text_fields,    'Text Report',    'Type or paste any field notes or observations',       kAccent),
      (_InputMode.image, Icons.camera_alt,     'Photo / Image',  'Capture or upload survey photos, handwritten notes',   const Color(0xFF8B5CF6)),
      (_InputMode.pdf,   Icons.picture_as_pdf, 'PDF / Document', 'Upload PDF reports, Word docs, or printed forms',      kRed),
      (_InputMode.excel, Icons.table_chart,    'Excel / CSV',    'Bulk upload spreadsheet — each row = one report',      kGreen),
      (_InputMode.voice, Icons.mic,            'Voice Note',     'Speak your report — AI transcribes and structures it', kOrange),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: kMuted.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('Choose Report Format', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Select how you want to submit your field data', style: TextStyle(color: kMuted, fontSize: 13)),
        const SizedBox(height: 20),
        ...formats.map((f) => GestureDetector(
          onTap: () => onSelected(f.$1),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: f.$5.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: f.$5.withOpacity(0.2)),
            ),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: f.$5.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(f.$2, color: f.$5, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f.$3, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(f.$4, style: const TextStyle(color: kMuted, fontSize: 12.5)),
              ])),
              Icon(Icons.chevron_right, color: f.$5, size: 20),
            ]),
          ),
        )),
      ]),
    );
  }
}

// ─── Input Sheet (mode-specific UI) ─────────────────────────────────────────
class _InputSheet extends StatelessWidget {
  final _InputMode mode;
  final TextEditingController textCtrl;
  final SpeechToText speech;
  final bool speechAvailable, loading, listening;
  final String voiceTranscript;
  final void Function(String) onTranscriptChange;
  final void Function(bool) onListeningChange;
  final void Function(Map) onSubmitResult;
  final void Function(List<Map>) onBatchResults;
  final void Function(bool) setLoading;

  const _InputSheet({
    required this.mode, required this.textCtrl, required this.speech,
    required this.speechAvailable, required this.loading, required this.listening,
    required this.voiceTranscript, required this.onTranscriptChange,
    required this.onListeningChange, required this.onSubmitResult,
    required this.onBatchResults, required this.setLoading,
  });

  Future<void> _submitText(BuildContext ctx) async {
    if (textCtrl.text.trim().isEmpty) return;
    setLoading(true);
    final res = await safePost('/ingest', {'text': textCtrl.text.trim(), 'source': 'ngo'});
    setLoading(false);
    if (res != null && res.statusCode == 200) {
      final data = jsonDecode(res.body)['data'] as Map;
      data['input_type'] = 'text';
      textCtrl.clear();
      onSubmitResult(data);
    } else {
      _snack(ctx, 'Submission failed', isError: true);
    }
  }

  Future<void> _pickImage(BuildContext ctx) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    setLoading(true);
    try {
      final bytes = await file.readAsBytes();
      final req = http.MultipartRequest('POST', Uri.parse('$kApiBase/upload/image'));
      req.files.add(http.MultipartFile.fromBytes('image', bytes, filename: file.name));
      req.fields['source'] = 'ngo';
      final stream = await req.send();
      final res = await http.Response.fromStream(stream);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'] as Map;
        data['input_type'] = 'image';
        onSubmitResult(data);
      } else { _snack(ctx, 'Image failed: ${jsonDecode(res.body)['error']}', isError: true); }
    } catch (e) { _snack(ctx, 'Upload error: $e', isError: true); }
    setLoading(false);
  }

  Future<void> _pickFile(BuildContext ctx, String endpoint, String fieldName, String inputType) async {
    final List<String> ext = inputType == 'excel' ? ['xlsx', 'xls', 'csv'] : ['pdf', 'doc', 'docx', 'txt'];
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ext, withData: true);
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;
    final file = result.files.first;
    setLoading(true);
    try {
      final req = http.MultipartRequest('POST', Uri.parse('$kApiBase/upload/$endpoint'));
      req.files.add(http.MultipartFile.fromBytes(fieldName, file.bytes!, filename: file.name!));
      req.fields['source'] = 'ngo';
      final stream = await req.send();
      final res = await http.Response.fromStream(stream);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['data'] is List) {
          final List<Map> results = (body['data'] as List).map((e) { final m = Map.from(e); m['input_type'] = inputType; return m; }).toList();
          onBatchResults(results);
        } else {
          final data = Map.from(body['data']); data['input_type'] = inputType;
          onSubmitResult(data);
        }
      } else { _snack(ctx, 'Upload failed', isError: true); }
    } catch (e) { _snack(ctx, 'Error: $e', isError: true); }
    setLoading(false);
  }

  Future<void> _toggleVoice() async {
    if (!speechAvailable) return;
    if (listening) {
      speech.stop(); onListeningChange(false);
    } else {
      onTranscriptChange('');
      await speech.listen(
        onResult: (r) => onTranscriptChange(r.recognizedWords),
        localeId: 'en_IN',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
      );
      onListeningChange(true);
    }
  }

  Future<void> _submitVoice(BuildContext ctx) async {
    if (voiceTranscript.trim().isEmpty) return;
    setLoading(true);
    final res = await safePost('/ingest', {'text': voiceTranscript.trim(), 'source': 'ngo'});
    setLoading(false);
    if (res != null && res.statusCode == 200) {
      final data = Map.from(jsonDecode(res.body)['data'] as Map);
      data['input_type'] = 'voice';
      onSubmitResult(data);
    } else { _snack(ctx, 'Submission failed', isError: true); }
  }

  @override
  Widget build(BuildContext context) {
    final titles = {
      _InputMode.text:  ('📝 Text Report',       kAccent),
      _InputMode.image: ('📸 Photo / Image',     const Color(0xFF8B5CF6)),
      _InputMode.pdf:   ('📄 PDF / Document',    kRed),
      _InputMode.excel: ('📊 Excel / CSV',       kGreen),
      _InputMode.voice: ('🎙️ Voice Note',        kOrange),
    };
    final (title, color) = titles[mode]!;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kMuted.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 20),
          if (mode == _InputMode.text) ...[
            _textField(textCtrl, 'Type or paste your field observations, survey notes, or situation report here...', maxLines: 6),
            const SizedBox(height: 14),
            _primaryButton(label: 'Send to Control Center', color: color, loading: loading, onTap: () => _submitText(context)),
          ] else if (mode == _InputMode.image) ...[
            _uploadTap(color, Icons.camera_alt, 'Choose Photo from Gallery', 'Survey photos, handwritten notes, or printed forms', loading ? 'Gemini Vision analyzing...' : null, () => _pickImage(context)),
          ] else if (mode == _InputMode.pdf) ...[
            _uploadTap(color, Icons.picture_as_pdf, 'Choose PDF or Document', 'PDF, Word (.docx), or text files', loading ? 'Processing document...' : null, () => _pickFile(context, 'excel', 'excel', 'pdf')),
          ] else if (mode == _InputMode.excel) ...[
            _uploadTap(color, Icons.table_chart, 'Choose Excel or CSV', 'Each row becomes a separate crisis report', loading ? 'Processing rows with Gemini...' : null, () => _pickFile(context, 'excel', 'excel', 'excel')),
          ] else if (mode == _InputMode.voice) ...[
            const SizedBox(height: 12),
            _voiceUI(context, color),
          ],
        ]),
      ),
    );
  }

  Widget _uploadTap(Color color, IconData icon, String label, String sub, String? loadingMsg, VoidCallback onTap) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.35), style: BorderStyle.solid),
        ),
        child: loadingMsg != null
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircularProgressIndicator(color: color, strokeWidth: 2),
                const SizedBox(height: 14),
                Text(loadingMsg, style: const TextStyle(color: kMuted, fontSize: 13)),
              ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 44, color: color.withOpacity(0.6)),
                const SizedBox(height: 10),
                Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Text(sub, style: const TextStyle(color: kMuted, fontSize: 12)),
              ]),
      ),
    );
  }

  Widget _voiceUI(BuildContext ctx, Color color) {
    return Column(children: [
      Center(
        child: GestureDetector(
          onTap: loading ? null : () async { await _toggleVoice(); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 96, height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: listening ? color.withOpacity(0.12) : kSurface2,
              border: Border.all(color: listening ? color : kMuted.withOpacity(0.3), width: listening ? 3 : 1),
              boxShadow: listening ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 24, spreadRadius: 4)] : [],
            ),
            child: Icon(listening ? Icons.stop : Icons.mic, color: listening ? color : kMuted, size: 40),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Center(child: Text(listening ? 'Listening... tap to stop' : 'Tap mic to start speaking', style: TextStyle(color: listening ? color : kMuted, fontSize: 13))),
      if (voiceTranscript.isNotEmpty) ...[
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Transcript', style: TextStyle(color: kMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Text(voiceTranscript, style: const TextStyle(fontSize: 14.5, height: 1.5)),
          ]),
        ),
        const SizedBox(height: 14),
        _primaryButton(label: 'Submit to Control Center', color: color, loading: loading, onTap: () => _submitVoice(ctx)),
      ],
    ]);
  }
}




void _snack(BuildContext context, String msg, {bool isError = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: isError ? kRed : kGreen,
  ));
}

Widget _resultWidget(Map r, Color accent) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: accent.withOpacity(0.06),
      border: Border.all(color: accent.withOpacity(0.25)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.auto_awesome, color: accent, size: 15),
        const SizedBox(width: 8),
        Text('AI Extracted & Logged', style: TextStyle(color: accent, fontWeight: FontWeight.w600, fontSize: 13)),
        const Spacer(),
        Text('${((r['confidence_score'] ?? 0.5) * 100).toStringAsFixed(0)}% conf',
            style: const TextStyle(color: kMuted, fontSize: 12)),
      ]),
      const SizedBox(height: 10),
      _infoRow('Need',     r['need_type'] ?? '-'),
      _infoRow('Location', r['location'] ?? '-'),
      _infoRow('Urgency',  r['urgency'] ?? '-'),
      _infoRow('People',   '${r['people_count'] ?? 1}'),
      _infoRow('Status',   r['status'] ?? 'pending'),
      if ((r['missing_fields'] as List?)?.isNotEmpty == true)
        _infoRow('⚠ Missing', (r['missing_fields'] as List).join(', ')),
    ]),
  );
}

PreferredSizeWidget _appBar(String title, Color color) {
  return AppBar(
    backgroundColor: kSurface,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    bottom: PreferredSize(preferredSize: const Size.fromHeight(2),
      child: Container(height: 2, color: color.withOpacity(0.6))),
  );
}

Widget _infoCard({required IconData icon, required Color color, required String title, required String subtitle}) {
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 22),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: kMuted, fontSize: 12.5, height: 1.4)),
      ])),
    ]),
  );
}

Widget _textField(TextEditingController ctrl, String hint, {int maxLines = 5}) {
  return TextField(
    controller: ctrl, maxLines: maxLines,
    style: const TextStyle(color: Colors.white, fontSize: 14.5),
    decoration: InputDecoration(
      filled: true, fillColor: kSurface,
      hintText: hint, hintStyle: const TextStyle(color: kMuted, fontSize: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kAccent, width: 1.5)),
    ),
  );
}

Widget _primaryButton({required String label, required Color color, required bool loading, required VoidCallback onTap}) {
  return ElevatedButton(
    onPressed: loading ? null : onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: color, foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
    ),
    child: loading
        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
  );
}

Widget _solidBtn(String label, Color color, VoidCallback onTap) {
  return ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0,
    ),
    child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
  );
}

Widget _ghostBtn(String label, Color color, VoidCallback onTap) {
  return OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: color, side: BorderSide(color: color.withOpacity(0.5)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
  );
}

Widget _urgBadge(String u) {
  final c = u == 'high' ? kRed : u == 'medium' ? kOrange : kGreen;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
    child: Text(u.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c)),
  );
}

Widget _infoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 90, child: Text('$label:', style: const TextStyle(color: kMuted, fontSize: 12.5))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500))),
    ]),
  );
}

Widget _emptyState({required IconData icon, required String msg, required Color color}) {
  return Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 64, color: color.withOpacity(0.3)),
      const SizedBox(height: 16),
      Text(msg, style: const TextStyle(color: kMuted, fontSize: 15)),
      const SizedBox(height: 8),
      const Text('Pull down to refresh', style: TextStyle(color: kMuted, fontSize: 12)),
    ]),
  );
}

