import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const TotoRushApp());
}

// ---------------- Toto skins ----------------
class TotoSkin {
  final String name;
  final int price;
  final Color body;
  final Color roof;
  const TotoSkin(this.name, this.price, this.body, this.roof);
}

const List<TotoSkin> skins = [
  TotoSkin('হলুদ টোটো', 0, Color(0xFFFFC107), Color(0xFF2E7D32)),
  TotoSkin('লাল টোটো', 100, Color(0xFFE53935), Color(0xFF212121)),
  TotoSkin('নীল টোটো', 250, Color(0xFF1E88E5), Color(0xFFFFFFFF)),
  TotoSkin('ফুলের টোটো', 500, Color(0xFFEC407A), Color(0xFF6A1B9A)),
  TotoSkin('সোনার টোটো', 1000, Color(0xFFFFD54F), Color(0xFFB71C1C)),
];

// ---------------- Save data ----------------
class Save {
  static int coins = 0;
  static int best = 0;
  static int selected = 0;
  static Set<int> owned = {0};

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    coins = p.getInt('coins') ?? 0;
    best = p.getInt('best') ?? 0;
    selected = p.getInt('selected') ?? 0;
    final list = p.getStringList('owned') ?? ['0'];
    owned = list.map(int.parse).toSet();
    owned.add(0);
  }

  static Future<void> store() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('coins', coins);
    await p.setInt('best', best);
    await p.setInt('selected', selected);
    await p.setStringList('owned', owned.map((e) => e.toString()).toList());
  }
}

// ---------------- Drawing helpers ----------------
Paint _p(Color c) => Paint()..color = c;

void drawText(Canvas c, String s, Offset center, double size, Color color,
    {bool bold = false}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontSize: size,
        color: color,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

// Toto (rear view). cx = center x, by = bottom (ground) y, w = width
void drawToto(Canvas c, double cx, double by, double w, TotoSkin s) {
  // wheels
  c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - w * 0.44, by - w * 0.28, w * 0.16, w * 0.28),
          Radius.circular(w * 0.04)),
      _p(const Color(0xFF212121)));
  c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + w * 0.28, by - w * 0.28, w * 0.16, w * 0.28),
          Radius.circular(w * 0.04)),
      _p(const Color(0xFF212121)));
  // body
  c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - w * 0.42, by - w * 0.62, w * 0.84, w * 0.48),
          Radius.circular(w * 0.08)),
      _p(s.body));
  // window
  c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - w * 0.3, by - w * 0.56, w * 0.6, w * 0.2),
          Radius.circular(w * 0.04)),
      _p(const Color(0xFF37474F)));
  // roof
  c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - w * 0.46, by - w * 0.78, w * 0.92, w * 0.18),
          Radius.circular(w * 0.07)),
      _p(s.roof));
  // tail lights
  c.drawCircle(Offset(cx - w * 0.32, by - w * 0.25), w * 0.05,
      _p(const Color(0xFFFF1744)));
  c.drawCircle(Offset(cx + w * 0.32, by - w * 0.25), w * 0.05,
      _p(const Color(0xFFFF1744)));
  // number plate
  c.drawRect(Rect.fromLTWH(cx - w * 0.1, by - w * 0.3, w * 0.2, w * 0.08),
      _p(Colors.white));
}

void _vehicle(Canvas c, double cx, double by, double w, double h, Color body,
    Color window) {
  c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - w / 2, by - h, w, h - w * 0.12),
          Radius.circular(w * 0.08)),
      _p(body));
  c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - w * 0.4, by - h + h * 0.1, w * 0.8, h * 0.32),
          Radius.circular(w * 0.04)),
      _p(window));
  c.drawCircle(
      Offset(cx - w * 0.3, by - h * 0.3), w * 0.06, _p(const Color(0xFFFF1744)));
  c.drawCircle(
      Offset(cx + w * 0.3, by - h * 0.3), w * 0.06, _p(const Color(0xFFFF1744)));
  c.drawRect(Rect.fromLTWH(cx - w * 0.42, by - w * 0.2, w * 0.16, w * 0.2),
      _p(const Color(0xFF212121)));
  c.drawRect(Rect.fromLTWH(cx + w * 0.26, by - w * 0.2, w * 0.16, w * 0.2),
      _p(const Color(0xFF212121)));
}

// type 3 = tall (must dodge), type 4 = low (can jump)
void drawObstacle(
    Canvas c, int type, int zone, int variant, double cx, double by, double lw) {
  final w = lw * 0.86;
  if (type == 3) {
    if (zone == 0) {
      // bullock cart with hay
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx - w * 0.45, by - w * 0.95, w * 0.9, w * 0.5),
              Radius.circular(w * 0.2)),
          _p(const Color(0xFFFDD835)));
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx - w / 2, by - w * 0.6, w, w * 0.35),
              Radius.circular(w * 0.05)),
          _p(const Color(0xFF6D4C41)));
      c.drawCircle(Offset(cx - w * 0.38, by - w * 0.2), w * 0.2,
          _p(const Color(0xFF3E2723)));
      c.drawCircle(Offset(cx + w * 0.38, by - w * 0.2), w * 0.2,
          _p(const Color(0xFF3E2723)));
      c.drawCircle(Offset(cx - w * 0.38, by - w * 0.2), w * 0.07,
          _p(const Color(0xFFBCAAA4)));
      c.drawCircle(Offset(cx + w * 0.38, by - w * 0.2), w * 0.07,
          _p(const Color(0xFFBCAAA4)));
    } else if (zone == 1) {
      final body =
          variant == 0 ? const Color(0xFFE53935) : const Color(0xFF3949AB);
      _vehicle(c, cx, by, w, w * 1.0, body, const Color(0xFFB3E5FC));
    } else {
      if (variant == 0) {
        // tram
        _vehicle(c, cx, by, w, w * 1.05, const Color(0xFF1976D2),
            const Color(0xFFE3F2FD));
        c.drawRect(Rect.fromLTWH(cx - w / 2, by - w * 0.5, w, w * 0.08),
            _p(Colors.white));
      } else {
        // yellow taxi
        _vehicle(c, cx, by, w, w * 0.9, const Color(0xFFFFC107),
            const Color(0xFF455A64));
        c.drawRect(Rect.fromLTWH(cx - w * 0.12, by - w * 0.98, w * 0.24, w * 0.08),
            _p(Colors.white));
      }
    }
  } else {
    final lh = w * 0.42;
    if (zone == 0) {
      // hay bale
      c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(cx - w / 2, by - lh, w, lh),
              Radius.circular(w * 0.1)),
          _p(const Color(0xFFFBC02D)));
      for (int i = 1; i < 4; i++) {
        c.drawRect(Rect.fromLTWH(cx - w / 2 + i * w / 4, by - lh, w * 0.03, lh),
            _p(const Color(0xFF8D6E63)));
      }
    } else {
      final c1 =
          zone == 1 ? const Color(0xFFFF6F00) : const Color(0xFFFFEB3B);
      final c2 = zone == 1 ? Colors.white : const Color(0xFF212121);
      for (int i = 0; i < 6; i++) {
        c.drawRect(
            Rect.fromLTWH(cx - w / 2 + i * w / 6, by - lh, w / 6, lh * 0.55),
            _p(i.isEven ? c1 : c2));
      }
      c.drawRect(Rect.fromLTWH(cx - w * 0.4, by - lh * 0.45, w * 0.08, lh * 0.45),
          _p(const Color(0xFF616161)));
      c.drawRect(Rect.fromLTWH(cx + w * 0.32, by - lh * 0.45, w * 0.08, lh * 0.45),
          _p(const Color(0xFF616161)));
    }
  }
}

// ---------------- App ----------------
class TotoRushApp extends StatelessWidget {
  const TotoRushApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Toto Rush',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.orange),
      home: const MenuScreen(),
    );
  }
}

class TotoPainter extends CustomPainter {
  final TotoSkin skin;
  TotoPainter(this.skin);
  @override
  void paint(Canvas canvas, Size size) {
    final w = min(size.width, size.height / 0.8) * 0.9;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.95),
            width: w * 0.9,
            height: w * 0.14),
        _p(Colors.black26));
    drawToto(canvas, size.width / 2, size.height * 0.95, w, skin);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ---------------- Menu ----------------
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool ready = false;

  @override
  void initState() {
    super.initState();
    Save.load().then((_) {
      if (mounted) setState(() => ready = true);
    });
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  Widget _bigBtn(String t, VoidCallback f) => SizedBox(
        width: 240,
        height: 56,
        child: ElevatedButton(
          onPressed: f,
          child: Text(t, style: const TextStyle(fontSize: 22)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4FC3F7), Color(0xFFFFE0B2)],
          ),
        ),
        child: SafeArea(
          child: !ready
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Toto Rush',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 220,
                        height: 170,
                        child: CustomPaint(
                            painter: TotoPainter(skins[Save.selected])),
                      ),
                      Text(
                        '🪙 ${Save.coins}   |   সেরা: ${Save.best} মি',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      _bigBtn('খেলো', () => _open(const GameScreen())),
                      const SizedBox(height: 12),
                      _bigBtn('টোটো দোকান', () => _open(const ShopScreen())),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

// ---------------- Shop ----------------
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  void _action(int i) {
    final s = skins[i];
    if (Save.owned.contains(i)) {
      Save.selected = i;
    } else if (Save.coins >= s.price) {
      Save.coins -= s.price;
      Save.owned.add(i);
      Save.selected = i;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('কয়েন কম আছে!')),
      );
      return;
    }
    Save.store();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('টোটো দোকান')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('🪙 ${Save.coins}',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: skins.length,
              itemBuilder: (context, i) {
                final s = skins[i];
                final owned = Save.owned.contains(i);
                final selected = Save.selected == i;
                String label;
                if (selected) {
                  label = 'ব্যবহার হচ্ছে';
                } else if (owned) {
                  label = 'ব্যবহার করো';
                } else {
                  label = 'কিনো';
                }
                return Card(
                  child: ListTile(
                    leading: SizedBox(
                      width: 70,
                      height: 60,
                      child: CustomPaint(painter: TotoPainter(s)),
                    ),
                    title: Text(s.name),
                    subtitle: Text(owned ? 'কেনা আছে' : '🪙 ${s.price}'),
                    trailing: ElevatedButton(
                      onPressed: selected ? null : () => _action(i),
                      child: Text(label),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Game ----------------
class Ent {
  int type; // 0 coin, 1 boost, 2 shield, 3 tall, 4 low
  int lane;
  double t;
  int variant;
  Ent(this.type, this.lane, this.t, this.variant);
}

class Scn {
  double t;
  int side;
  int variant;
  Scn(this.t, this.side, this.variant);
}

const double pT = 0.8; // player depth

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  final Random rnd = Random();
  Duration _last = Duration.zero;

  final List<Ent> ents = [];
  final List<Scn> scn = [];
  int targetLane = 1;
  double laneAnim = 1;
  double jumpH = 0;
  double jumpV = 0;
  double dist = 0;
  int runCoins = 0;
  double boostT = 0;
  bool shield = false;
  bool over = false;
  double spawnAcc = 0;
  double scnAcc = 0;
  double scroll = 0;
  int zone = 0;
  double bannerT = 2.5;
  String banner = 'গ্রামের পথ';
  int scnSide = 0;
  double topPad = 0;

  double _dx = 0;
  double _dy = 0;
  bool _handled = false;

  static const zoneNames = ['গ্রামের পথ', 'শহরের রাস্তা', 'কলকাতার রাস্তা'];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double get speed {
    double s = 0.42 + min(0.30, dist / 4000 * 0.30);
    if (boostT > 0) s *= 1.5;
    return s;
  }

  void _onTick(Duration elapsed) {
    var dt = (elapsed - _last).inMicroseconds / 1000000.0;
    _last = elapsed;
    if (dt > 0.05) dt = 0.05;
    if (dt <= 0) return;
    if (!over) _update(dt);
    _repaint.value++;
  }

  void _update(double dt) {
    final sp = speed;
    dist += sp * dt * 60;
    scroll += sp * dt;
    if (boostT > 0) boostT -= dt;
    laneAnim += (targetLane - laneAnim) * min(1.0, dt * 12);

    if (jumpH > 0 || jumpV > 0) {
      jumpV -= 9.0 * dt;
      jumpH += jumpV * dt;
      if (jumpH <= 0) {
        jumpH = 0;
        jumpV = 0;
      }
    }

    final z = (dist ~/ 500) % 3;
    if (z != zone) {
      zone = z;
      banner = zoneNames[z];
      bannerT = 2.5;
    }
    if (bannerT > 0) bannerT -= dt;

    for (final e in ents) {
      e.t += sp * dt;
    }
    for (final s in scn) {
      s.t += sp * dt;
    }
    ents.removeWhere((e) => e.t > 1.15);
    scn.removeWhere((s) => s.t > 1.3);

    spawnAcc += sp * dt;
    if (spawnAcc >= 0.30) {
      spawnAcc -= 0.30;
      _spawnRow();
    }
    scnAcc += sp * dt;
    if (scnAcc >= 0.10) {
      scnAcc -= 0.10;
      scn.add(Scn(0, scnSide, rnd.nextInt(3)));
      scnSide = 1 - scnSide;
    }

    for (final e in ents) {
      if (e.t < pT - 0.05 || e.t > pT + 0.03) continue;
      if ((e.lane - laneAnim).abs() > 0.55) continue;
      if (e.type == 0) {
        runCoins++;
        e.t = 9;
      } else if (e.type == 1) {
        boostT = 4;
        e.t = 9;
      } else if (e.type == 2) {
        shield = true;
        e.t = 9;
      } else {
        if (e.type == 4 && jumpH > 0.25) continue;
        if (boostT > 0) {
          e.t = 9;
          continue;
        }
        if (shield) {
          shield = false;
          e.t = 9;
          continue;
        }
        _gameOver();
        return;
      }
    }
  }

  void _spawnRow() {
    final r = rnd.nextInt(10);
    final lanes = [0, 1, 2]..shuffle(rnd);
    if (r < 4) {
      final n = rnd.nextBool() ? 1 : 2;
      final type = rnd.nextInt(3) == 0 ? 4 : 3;
      for (int i = 0; i < n; i++) {
        ents.add(Ent(type, lanes[i], 0, rnd.nextInt(2)));
      }
      if (rnd.nextBool()) ents.add(Ent(0, lanes[n], 0, 0));
    } else if (r < 8) {
      final l = lanes[0];
      for (int i = 0; i < 4; i++) {
        ents.add(Ent(0, l, -i * 0.07, 0));
      }
    } else if (r == 8) {
      ents.add(Ent(rnd.nextBool() ? 1 : 2, lanes[0], 0, 0));
    }
  }

  void _gameOver() {
    over = true;
    _ticker.stop();
    Save.coins += runCoins;
    final score = dist.toInt();
    if (score > Save.best) Save.best = score;
    Save.store();
    setState(() {});
  }

  void _restart() {
    setState(() {
      ents.clear();
      scn.clear();
      targetLane = 1;
      laneAnim = 1;
      jumpH = 0;
      jumpV = 0;
      dist = 0;
      runCoins = 0;
      boostT = 0;
      shield = false;
      over = false;
      spawnAcc = 0;
      scnAcc = 0;
      scroll = 0;
      zone = 0;
      banner = zoneNames[0];
      bannerT = 2.5;
    });
    _last = Duration.zero;
    _ticker.start();
  }

  void _leave() {
    if (!over) {
      Save.coins += runCoins;
      final s = dist.toInt();
      if (s > Save.best) Save.best = s;
      Save.store();
    }
    Navigator.pop(context);
  }

  void _left() {
    if (!over && targetLane > 0) targetLane--;
  }

  void _right() {
    if (!over && targetLane < 2) targetLane++;
  }

  void _jump() {
    if (!over && jumpH == 0 && jumpV == 0) jumpV = 3.2;
  }

  Widget _btn(IconData icon, VoidCallback f) {
    return GestureDetector(
      onTapDown: (_) => f(),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white70, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 38),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    topPad = MediaQuery.of(context).padding.top;
    const white = TextStyle(color: Colors.white, fontSize: 22);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) {
                _dx = 0;
                _dy = 0;
                _handled = false;
              },
              onPanUpdate: (d) {
                if (_handled) return;
                _dx += d.delta.dx;
                _dy += d.delta.dy;
                if (_dx.abs() > 30 && _dx.abs() > _dy.abs()) {
                  if (_dx > 0) {
                    _right();
                  } else {
                    _left();
                  }
                  _handled = true;
                } else if (_dy < -30 && _dy.abs() > _dx.abs()) {
                  _jump();
                  _handled = true;
                }
              },
              child: CustomPaint(
                painter: GamePainter(this),
                size: Size.infinite,
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _btn(Icons.arrow_back, _left),
                  _btn(Icons.arrow_upward, _jump),
                  _btn(Icons.arrow_forward, _right),
                ],
              ),
            ),
          ),
          Positioned(
            top: 4,
            left: 4,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: _leave,
              ),
            ),
          ),
          if (over)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('গেম শেষ!',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text('দূরত্ব: ${dist.toInt()} মি', style: white),
                      Text('কয়েন: $runCoins', style: white),
                      Text('সেরা: ${Save.best} মি', style: white),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _restart,
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Text('আবার খেলো',
                              style: TextStyle(fontSize: 22)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _leave,
                        child: const Text('মেনু',
                            style:
                                TextStyle(color: Colors.white, fontSize: 20)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------- Painter ----------------
const List<Color> skyTop = [
  Color(0xFF4FC3F7),
  Color(0xFF90A4AE),
  Color(0xFFFFB74D)
];
const List<Color> skyBot = [
  Color(0xFFE1F5FE),
  Color(0xFFECEFF1),
  Color(0xFFFFE0B2)
];
const List<Color> groundCol = [
  Color(0xFF7CB342),
  Color(0xFF9E9E9E),
  Color(0xFFD7CCC8)
];
const List<Color> roadCol = [
  Color(0xFF8D6E63),
  Color(0xFF424242),
  Color(0xFF37474F)
];

class GamePainter extends CustomPainter {
  final _GameScreenState g;
  GamePainter(this.g) : super(repaint: g._repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.30;
    final zone = g.zone;

    double rw(double p) => w * (0.14 + 0.82 * p);
    double ypos(double p) => horizon + (h - horizon) * p;

    // sky
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, horizon + 2),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [skyTop[zone], skyBot[zone]],
        ).createShader(Rect.fromLTWH(0, 0, w, horizon)),
    );
    canvas.drawCircle(Offset(w * 0.78, horizon * 0.5), w * 0.09,
        _p(const Color(0xFFFFEB3B)));

    // skyline
    if (zone == 0) {
      canvas.drawCircle(
          Offset(w * 0.2, horizon), w * 0.18, _p(const Color(0xFF558B2F)));
      canvas.drawCircle(
          Offset(w * 0.7, horizon), w * 0.22, _p(const Color(0xFF689F38)));
    } else {
      for (int i = 0; i < 10; i++) {
        final hh = 20.0 + ((i * 37) % 50);
        canvas.drawRect(
          Rect.fromLTWH(i * w / 10, horizon - hh, w / 10 - 3, hh),
          _p(zone == 1
              ? const Color(0xFF78909C)
              : (i.isEven
                  ? const Color(0xFFFFAB91)
                  : const Color(0xFFFFCC80))),
        );
      }
    }

    // ground
    canvas.drawRect(
        Rect.fromLTWH(0, horizon, w, h - horizon), _p(groundCol[zone]));

    // road
    final road = Path()
      ..moveTo(w / 2 - rw(0) / 2, horizon)
      ..lineTo(w / 2 + rw(0) / 2, horizon)
      ..lineTo(w / 2 + rw(1) / 2, h)
      ..lineTo(w / 2 - rw(1) / 2, h)
      ..close();
    canvas.drawPath(road, _p(roadCol[zone]));

    final edge = Paint()
      ..color = Colors.white
      ..strokeWidth = 3;
    canvas.drawLine(
        Offset(w / 2 - rw(0) / 2, horizon), Offset(w / 2 - rw(1) / 2, h), edge);
    canvas.drawLine(
        Offset(w / 2 + rw(0) / 2, horizon), Offset(w / 2 + rw(1) / 2, h), edge);

    // lane dashes
    const n = 8;
    final phase = (g.scroll % (1.0 / n)) / (1.0 / n);
    for (int k = 0; k < n; k++) {
      final t0 = (k + phase) / n;
      final t1 = t0 + 0.5 / n;
      final pa = t0 * t0;
      final pb = t1 * t1;
      for (final sgn in [-1.0, 1.0]) {
        final path = Path()
          ..moveTo(w / 2 + sgn * rw(pa) / 6 - rw(pa) * 0.01, ypos(pa))
          ..lineTo(w / 2 + sgn * rw(pa) / 6 + rw(pa) * 0.01, ypos(pa))
          ..lineTo(w / 2 + sgn * rw(pb) / 6 + rw(pb) * 0.01, ypos(pb))
          ..lineTo(w / 2 + sgn * rw(pb) / 6 - rw(pb) * 0.01, ypos(pb))
          ..close();
        canvas.drawPath(path, _p(Colors.white70));
      }
    }

    // scenery (far to near)
    for (final s in g.scn.reversed) {
      if (s.t < 0.02) continue;
      final p = s.t * s.t;
      final lw = rw(p) / 3;
      final side = s.side == 0 ? -1.0 : 1.0;
      final by = ypos(p);
      final x = w / 2 + side * (rw(p) / 2 + lw * (0.5 + 0.35 * s.variant));
      if (zone == 0) {
        canvas.drawRect(Rect.fromLTWH(x - lw * 0.08, by - lw * 0.6, lw * 0.16, lw * 0.6),
            _p(const Color(0xFF5D4037)));
        canvas.drawCircle(Offset(x, by - lw * 0.85), lw * 0.5,
            _p(const Color(0xFF2E7D32)));
      } else {
        final bw = lw * 1.0;
        final bh = lw * (1.6 + 0.6 * s.variant);
        Color bc;
        if (zone == 1) {
          bc = const Color(0xFF607D8B);
        } else {
          bc = [
            const Color(0xFFFFCC80),
            const Color(0xFFF48FB1),
            const Color(0xFF80CBC4)
          ][s.variant];
        }
        canvas.drawRect(Rect.fromLTWH(x - bw / 2, by - bh, bw, bh), _p(bc));
        canvas.drawRect(Rect.fromLTWH(x - bw / 2, by - bh, bw, bh * 0.06),
            _p(const Color(0xFF4E342E)));
        for (int r = 0; r < 3; r++) {
          for (int cc = 0; cc < 2; cc++) {
            canvas.drawRect(
              Rect.fromLTWH(x - bw * 0.35 + cc * bw * 0.4, by - bh * 0.85 + r * bh * 0.27,
                  bw * 0.25, bh * 0.14),
              _p(const Color(0xFFFFF9C4)),
            );
          }
        }
      }
    }

    // entities
    final sorted = [...g.ents]..sort((a, b) => a.t.compareTo(b.t));
    void drawEnt(Ent e) {
      if (e.t < 0.03) return;
      final p = e.t * e.t;
      final lw = rw(p) / 3;
      final cx = w / 2 + (e.lane - 1) * lw;
      final by = ypos(p);
      if (e.type == 0) {
        canvas.drawCircle(Offset(cx, by - lw * 0.25), lw * 0.14,
            _p(const Color(0xFFFFC107)));
        canvas.drawCircle(Offset(cx, by - lw * 0.25), lw * 0.09,
            _p(const Color(0xFFFFE082)));
      } else if (e.type == 1) {
        canvas.drawCircle(
            Offset(cx, by - lw * 0.3), lw * 0.22, _p(const Color(0xFFFF6D00)));
        drawText(canvas, '⚡', Offset(cx, by - lw * 0.3), lw * 0.28, Colors.white);
      } else if (e.type == 2) {
        canvas.drawCircle(
            Offset(cx, by - lw * 0.3), lw * 0.22, _p(const Color(0xFF00ACC1)));
        drawText(canvas, '🛡️', Offset(cx, by - lw * 0.3), lw * 0.28, Colors.white);
      } else {
        drawObstacle(canvas, e.type, zone, e.variant, cx, by, lw);
      }
    }

    for (final e in sorted) {
      if (e.t <= pT) drawEnt(e);
    }

    // player
    final pp = pT * pT;
    final plw = rw(pp) / 3;
    final pcx = w / 2 + (g.laneAnim - 1) * plw;
    final pby = ypos(pp);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(pcx, pby), width: plw * 0.8, height: plw * 0.16),
        _p(Colors.black26));
    final jumpPx = g.jumpH * plw * 1.1;
    if (g.boostT > 0) {
      final lp = Paint()
        ..color = Colors.orangeAccent
        ..strokeWidth = 4;
      for (int i = -1; i <= 1; i++) {
        canvas.drawLine(Offset(pcx + i * plw * 0.25, pby - jumpPx + plw * 0.05),
            Offset(pcx + i * plw * 0.25, pby - jumpPx + plw * 0.45), lp);
      }
    }
    drawToto(canvas, pcx, pby - jumpPx, plw * 0.78, skins[Save.selected]);
    if (g.shield) {
      final c = Offset(pcx, pby - jumpPx - plw * 0.3);
      canvas.drawCircle(c, plw * 0.6, _p(const Color(0x4400E5FF)));
      canvas.drawCircle(
          c,
          plw * 0.6,
          Paint()
            ..color = const Color(0xFF00E5FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }

    for (final e in sorted) {
      if (e.t > pT) drawEnt(e);
    }

    // HUD
    final hy = g.topPad + 30;
    drawText(canvas, '${g.dist.toInt()} মি', Offset(w / 2, hy), 24, Colors.white,
        bold: true);
    drawText(canvas, '🪙 ${g.runCoins}', Offset(w - 60, hy), 22, Colors.white,
        bold: true);
    if (g.boostT > 0) {
      drawText(canvas, '⚡ ${g.boostT.ceil()}', Offset(w - 60, hy + 32), 20,
          Colors.white,
          bold: true);
    }
    if (g.shield) {
      drawText(canvas, '🛡️', Offset(w - 60, hy + 64), 22, Colors.white);
    }
    if (g.bannerT > 0) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(w / 2, h * 0.2), width: w * 0.8, height: 56),
              const Radius.circular(14)),
          _p(const Color(0x99000000)));
      drawText(canvas, g.banner, Offset(w / 2, h * 0.2), 28, Colors.white,
          bold: true);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
