import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:getgabs/domain/controllers/auth/login_with_email/login_with_email_controller.dart';
import 'package:getgabs/ui/res/assets/image_assets.dart';
import 'package:getgabs/ui/res/widgets/reusable_widgets.dart';
import 'package:getgabs/ui/themes/themes.dart';
import '../../../res/utils/predefined_logics_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  COLOR PALETTE
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  /// Check karta hai ki current flavor 'messagedly' hai ya nahi
  static bool get isMessagedly => LoginWithEmailController.currentFlavorNormalized == 'messagedly';

  /// Check karta hai ki current flavor 'scalewiz' hai ya nahi
  static bool get isScalewiz => LoginWithEmailController.currentFlavorNormalized == 'scalewiz';

  // Base background dono apps mein same rahega
  static const bg = Color(0xFF0A0F0D);

  // Placeholder bhi dono ke liye same rahega
  static const placeholder = Color(0xFF3A5248);

  // ── Dynamic Color Switching based on Flavor ──

  static Color get card => isMessagedly
      ? const Color(0xFF162019)
      : isScalewiz
          ? const Color(0xFF0F1E1C)
          : const Color(0xFF162019); // Agar messagedly ke liye card color badalna ho toh yahan change karein

  static Color get green => isMessagedly
      ? const Color.fromARGB(255, 150, 107, 219)
      : isScalewiz
          ? const Color(0xff17A398)
          : const Color(0xFF25D366);

  static Color get greenDark => isMessagedly
      ? const Color.fromARGB(255, 125, 139, 216)
      : isScalewiz
          ? const Color(0xff0E7C74)
          : const Color(0xFF128C7E);

  static Color get border => isMessagedly
      ? const Color.fromARGB(33, 17, 17, 17)
      : isScalewiz
          ? const Color(0x2217A398)
          : const Color(0x2225D366);

  static Color get text => isMessagedly
      ? const Color.fromARGB(255, 229, 231, 248)
      : isScalewiz
          ? const Color(0xFFE9F7F4)
          : const Color(0xFFF0FAF4);

  static Color get muted => isMessagedly
      ? const Color.fromARGB(255, 164, 135, 245)
      : isScalewiz
          ? const Color(0xff5FA79D)
          : const Color(0xFF6B8F79);
}

// ─────────────────────────────────────────────────────────────────────────────
//  LOGIN SCREEN  —  StatelessWidget
// ─────────────────────────────────────────────────────────────────────────────
class LoginWithEmailScreen extends StatelessWidget {
  LoginWithEmailScreen({super.key});

//   GlobalKey<FormState> loginScreenFormKey = GlobalKey<FormState>();
    final LoginWithEmailController c = Get.put(LoginWithEmailController());

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context).size;
    final hp = mq.height;
    final wp = mq.width;

    return Scaffold(
      // backgroundColor: _C.bg,
      body: Stack(children: [

        // ── Blobs ──────────────────────────────────────────────────────────
        _Blob(anim: c.blobAnim, color: _C.green,
              size: wp * 0.95, top: -wp * 0.22, right: -wp * 0.18),
        _Blob(anim: c.blobAnim, color: _C.greenDark,
              size: wp * 0.70, bottom: -wp * 0.18, left: -wp * 0.18, reversed: true),

        // ── Grid ───────────────────────────────────────────────────────────
        Positioned.fill(child: CustomPaint(painter: _GridPainter())),

        // ── Scroll content ─────────────────────────────────────────────────
        SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: wp * 0.07, vertical: hp * 0.015),
            child: Form(
              key: c.formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

                SizedBox(height: hp * 0.018),

                // Badge — Scalewiz is not a Meta Official Partner, so this is
                // hidden for that flavor only.
                if (!_C.isScalewiz)
                  _Anim(opacity: c.opacity(0.00, 0.40),
                        offset:  c.offset(0.00, 0.40, start: const Offset(0, -0.22)),
                        child: const Center(child: _Badge())),

                // SizedBox(height: hp * 0.030),

                // Logo
                _Anim(opacity: c.opacity(0.10, 0.50),
                      offset:  c.offset(0.10, 0.50, start: const Offset(0, -0.18)),
                      child: const _LogoSection()),

                SizedBox(height: hp * 0.038),

                // Email field
                _Anim(opacity: c.opacity(0.22, 0.62),
                      offset:  c.offset(0.22, 0.62),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const _Label('USERNAME OR EMAIL'),
                        const SizedBox(height: 8),
                        _InputField(
                          controller: c.emailCtrl,
                          focusNode:  c.emailFocus,
                          hint:       'Enter username or email',
                          icon:       Icons.person_outline_rounded,
                          keyboard:   TextInputType.emailAddress,
                          onSubmit:   (_) => FocusScope.of(context).requestFocus(c.pwFocus),
                          validator:  (v) => (v == null || v.isEmpty)
                                            ? "This field can't be empty" : null,
                        ),
                      ])),

                SizedBox(height: hp * 0.022),

                // Password field — Obx for obscure toggle
                _Anim(opacity: c.opacity(0.28, 0.68),
                      offset:  c.offset(0.28, 0.68),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const _Label('PASSWORD'),
                        const SizedBox(height: 8),
                        Obx(() => _InputField(
                          controller: c.passwordCtrl,
                          focusNode:  c.pwFocus,
                          hint:       'Enter password',
                          icon:       Icons.lock_outline_rounded,
                          obscure:    c.obscure.value,
                          suffix: IconButton(
                            icon: Icon(
                              c.obscure.value
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: _C.muted, size: 20,
                            ),
                            onPressed: c.toggleObscure,
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                                          ? "This field can't be empty" : null,
                        )),
                      ])),

                SizedBox(height: hp * 0.032),

                // Login button
                _Anim(opacity: c.opacity(0.38, 0.78),
                      offset:  c.offset(0.38, 0.78),
                      child: _LoginButton(onTap: c.onLogin)),

                SizedBox(height: hp * 0.028),

                // Trusted by divider
                // _Anim(opacity: c.opacity(0.48, 0.85),
                //       offset:  c.offset(0.48, 0.85),
                //       child: const _TrustedDivider()),

                SizedBox(height: hp * 0.018),

                // Stats
                // _Anim(opacity: c.opacity(0.54, 0.90),
                //       offset:  c.offset(0.54, 0.90),
                //       child: const _StatsRow()),

                SizedBox(height: hp * 0.038),

                // Footer
                _Anim(opacity: c.opacity(0.65, 1.00),
                      offset:  c.offset(0.65, 1.00),
                      child: const _Footer()),

                SizedBox(height: hp * 0.020),
                SizedBox(height: hp * 0.038),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ANIMATION WRAPPER
// ─────────────────────────────────────────────────────────────────────────────
class _Anim extends StatelessWidget {
  final Animation<double> opacity;
  final Animation<Offset> offset;
  final Widget child;
  const _Anim({required this.opacity, required this.offset, required this.child});

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: opacity,
          child: SlideTransition(position: offset, child: child));
}

// ─────────────────────────────────────────────────────────────────────────────
//  FLOATING BLOB
// ─────────────────────────────────────────────────────────────────────────────
class _Blob extends StatelessWidget {
  final Animation<double> anim;
  final Color  color;
  final double size;
  final double? top, bottom, left, right;
  final bool reversed;

  const _Blob({
    required this.anim, required this.color, required this.size,
    this.top, this.bottom, this.left, this.right, this.reversed = false,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: anim,
    builder: (_, __) {
      final dy = reversed ? -(1 - anim.value) * 18 : -anim.value * 18;
      return Positioned(
        top:    top    != null ? top!    + dy : null,
        bottom: bottom != null ? bottom! + dy : null,
        left: left, right: right,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.10),
          ),
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  GRID PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF25D366).withOpacity(0.03)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width;  x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }
  @override bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  PULSING BADGE
// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatefulWidget {
  const _Badge();
  @override State<_Badge> createState() => _BadgeState();
}
class _BadgeState extends State<_Badge> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat(reverse: true);
  late final Animation<double> _pulse =
      Tween<double>(begin: 1.0, end: 0.25)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: _C.green.withOpacity(0.10),
      borderRadius: BorderRadius.circular(100),
      border: Border.all(color: _C.green.withOpacity(0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      // FadeTransition(
      //   opacity: _pulse,
      //   child: Container(width: 6, height: 6,
      //       decoration: const BoxDecoration(color: _C.green, shape: BoxShape.circle))),
      SvgPicture.asset(ImageAssets.metaIcon, height: 24, width: 24,),
      const SizedBox(width: 7),
      Text('Meta Official Partner',
          style: TextStyle(color: _C.greenDark, fontSize: 12,
              fontWeight: FontWeight.w600, letterSpacing: 0.4)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  LOGO SECTION
// ─────────────────────────────────────────────────────────────────────────────
class _LogoSection extends StatelessWidget {
  const _LogoSection();

  @override
  Widget build(BuildContext context) => Column(children: [
    // Container(
    //   width: 72, height: 72,
    //   decoration: BoxDecoration(
    //     gradient: const LinearGradient(
    //       colors: [_C.green, _C.greenDark],
    //       begin: Alignment.topLeft, end: Alignment.bottomRight,
    //     ),
    //     borderRadius: BorderRadius.circular(22),
    //     boxShadow: [BoxShadow(
    //         color: _C.green.withOpacity(0.28),
    //         blurRadius: 28, offset: const Offset(0, 8))],
    //   ),
    //   child: const Center(child: _WAIcon()),
    // ),
           Image.asset(ImageAssets.getgabsLogoPng,
                width: double.infinity,
                // height: mediaQuery.height * 0.18, 
                height: 150,
                // width: mediaQuery.width * 0.45,
                // height: mediaQuery.height * 0.12,
                fit: BoxFit.contain, 
                ),
    // const SizedBox(height: 16),
    // RichText(text: const TextSpan(children: [
    //   TextSpan(text: 'Gabs',
    //       style: TextStyle(color: _C.text, fontSize: 26,
    //           fontWeight: FontWeight.w800, letterSpacing: -0.5)),
    //   TextSpan(text: '.',
    //       style: TextStyle(color: _C.green, fontSize: 26,
    //           fontWeight: FontWeight.w800)),
    // ])),
    // const SizedBox(height: 6),
    Text('Experience the power of WhatsApp Business API',
        textAlign: TextAlign.center,
        style: TextStyle(color: _C.muted, fontSize: 15, height: 1.5, fontWeight: FontWeight.bold)),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
//  WHATSAPP ICON
// ─────────────────────────────────────────────────────────────────────────────
class _WAIcon extends StatelessWidget {
  const _WAIcon();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(36, 36), painter: _WAPainter());
}

class _WAPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p  = Paint()..color = Colors.white;
    final sx = size.width / 24;
    final sy = size.height / 24;
    final path = Path()
      ..moveTo(17.472*sx,14.382*sy)
      ..cubicTo(17.175*sx,14.233*sy,15.714*sx,13.515*sy,15.442*sx,13.415*sy)
      ..cubicTo(15.169*sx,13.316*sy,14.971*sx,13.267*sy,14.772*sx,13.565*sy)
      ..cubicTo(14.575*sx,13.862*sy,14.005*sx,14.531*sy,13.832*sx,14.729*sy)
      ..cubicTo(13.659*sx,14.928*sy,13.485*sx,14.952*sy,13.188*sx,14.804*sy)
      ..cubicTo(12.891*sx,14.654*sy,11.933*sx,14.341*sy,10.798*sx,13.329*sy)
      ..cubicTo(9.915*sx,12.541*sy,9.318*sx,11.568*sy,9.145*sx,11.270*sy)
      ..cubicTo(8.972*sx,10.973*sy,9.127*sx,10.812*sy,9.275*sx,10.664*sy)
      ..cubicTo(9.409*sx,10.531*sy,9.573*sx,10.317*sy,9.721*sx,10.144*sy)
      ..cubicTo(9.870*sx,9.970*sy,9.919*sx,9.846*sy,10.019*sx,9.647*sy)
      ..cubicTo(10.118*sx,9.449*sy,10.069*sx,9.276*sy,9.994*sx,9.127*sy)
      ..cubicTo(9.919*sx,8.978*sy,9.325*sx,7.515*sy,9.078*sx,6.920*sy)
      ..cubicTo(8.836*sx,6.341*sy,8.591*sx,6.420*sy,8.409*sx,6.410*sy)
      ..cubicTo(8.236*sx,6.402*sy,8.038*sx,6.400*sy,7.839*sx,6.400*sy)
      ..cubicTo(7.641*sx,6.400*sy,7.319*sx,6.474*sy,7.047*sx,6.772*sy)
      ..cubicTo(6.775*sx,7.069*sy,6.007*sx,7.788*sy,6.007*sx,9.251*sy)
      ..cubicTo(6.007*sx,10.713*sy,7.072*sx,12.126*sy,7.220*sx,12.325*sy)
      ..cubicTo(7.369*sx,12.523*sy,9.316*sx,15.525*sy,12.297*sx,16.812*sy)
      ..cubicTo(13.006*sx,17.118*sy,13.559*sx,17.301*sy,13.991*sx,17.437*sy)
      ..cubicTo(14.703*sx,17.664*sy,15.351*sx,17.632*sy,15.862*sx,17.555*sy)
      ..cubicTo(16.433*sx,17.470*sy,17.620*sx,16.836*sy,17.868*sx,16.142*sy)
      ..cubicTo(18.116*sx,15.448*sy,18.116*sx,14.853*sy,18.041*sx,14.729*sy)
      ..cubicTo(17.967*sx,14.605*sy,17.769*sx,14.531*sy,17.472*sx,14.382*sy)
      ..close()
      ..moveTo(12.051*sx,0)
      ..cubicTo(5.495*sx,0,0.160*sx,5.335*sy,0.157*sx,11.892*sy)
      ..cubicTo(0.157*sx,13.988*sy,0.704*sx,16.034*sy,1.745*sx,17.837*sy)
      ..lineTo(0.057*sx,24*sy)
      ..lineTo(6.362*sx,22.346*sy)
      ..cubicTo(8.103*sx,23.293*sy,10.058*sx,23.794*sy,12.051*sx,23.794*sy)
      ..lineTo(12.056*sx,23.794*sy)
      ..cubicTo(18.610*sx,23.794*sy,23.946*sx,18.459*sy,23.949*sx,11.901*sy)
      ..cubicTo(23.951*sx,8.561*sy,22.663*sx,5.420*sy,20.469*sx,3.488*sy)
      ..cubicTo(18.276*sx,1.556*sy,15.290*sx,0,12.051*sx,0)
      ..close();
    canvas.drawPath(path, p);
  }
  @override bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  FIELD LABEL
// ─────────────────────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(color: _C.muted, fontSize: 11,
          fontWeight: FontWeight.w600, letterSpacing: 1.0));
}

// ─────────────────────────────────────────────────────────────────────────────
//  INPUT FIELD
// ─────────────────────────────────────────────────────────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode  focusNode;
  final String     hint;
  final IconData   icon;
  final bool       obscure;
  final TextInputType keyboard;
  final Widget?    suffix;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmit;

  const _InputField({
    required this.controller, required this.focusNode,
    required this.hint,       required this.icon,
    this.obscure  = false,
    this.keyboard = TextInputType.text,
    this.suffix, this.validator, this.onSubmit,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller:       controller,
    focusNode:        focusNode,
    obscureText:      obscure,
    keyboardType:     keyboard,
    onFieldSubmitted: onSubmit,
    onTapOutside:     (_) => FocusScope.of(context).unfocus(),
    validator:        validator,
    // style:       const TextStyle(color: _C.text, fontSize: 14),
    style:       TextStyle(color: _C.card, fontSize: 14),
    cursorColor: _C.green,
    decoration: InputDecoration(
      hintText:  hint,
      hintStyle: const TextStyle(color: _C.placeholder, fontSize: 14),
      filled:    true,
      fillColor: _C.text,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      prefixIcon: Icon(icon, color: _C.muted, size: 20),
      suffixIcon: suffix,
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _C.border, width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _C.green, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
      errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  LOGIN BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _LoginButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LoginButton({required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      gradient: LinearGradient(
          colors: [_C.green, _C.greenDark],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      boxShadow: [BoxShadow(
          color: _C.green.withOpacity(0.28),
          blurRadius: 24, offset: const Offset(0, 8))],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Login', style: TextStyle(color: Colors.white, fontSize: 15,
                fontWeight: FontWeight.w700, letterSpacing: 0.3)),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
          ]),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  TRUSTED BY DIVIDER
// ─────────────────────────────────────────────────────────────────────────────
class _TrustedDivider extends StatelessWidget {
  const _TrustedDivider();
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Container(height: 1, color: _C.border)),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text('TRUSTED BY', style: TextStyle(
          color: _C.muted, fontSize: 10,
          fontWeight: FontWeight.w500, letterSpacing: 1)),
    ),
    Expanded(child: Container(height: 1, color: _C.border)),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
//  STATS ROW
// ─────────────────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  const _StatsRow();
  @override
  Widget build(BuildContext context) => const Row(children: [
    _Stat('10K+',  'Businesses'),
    SizedBox(width: 10),
    _Stat('50M+',  'Messages'),
    SizedBox(width: 10),
    _Stat('99.9%', 'Uptime'),
  ]);
}

class _Stat extends StatelessWidget {
  final String value, label;
  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(
            color: _C.green, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(
            color: _C.text, fontSize: 10,
            fontWeight: FontWeight.w500, letterSpacing: 0.3)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  FOOTER
// ─────────────────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) => RichText(
    textAlign: TextAlign.center,
    text: TextSpan(
      style: TextStyle(color: _C.muted, fontSize: 11, height: 1.7),
      children: [
        const TextSpan(text: 'By continuing, you agree to our\n'),
        TextSpan(text: 'Terms of Use',
            style: TextStyle(color: _C.green, fontWeight: FontWeight.w600)),
        const TextSpan(text: ' & '),
        TextSpan(text: 'Privacy Policy',
            style: TextStyle(color: _C.green, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

// class LoginWithEmailScreen extends StatelessWidget {
//   LoginWithEmailScreen({super.key});

//   // final LoginWithEmailController loginWithEmailController =
//   //     Get.put(LoginWithEmailController());
//   GlobalKey<FormState> loginScreenFormKey = GlobalKey<FormState>();
//   @override
//   Widget build(BuildContext context) {
//     final LoginWithEmailController controller =
//       Get.put(LoginWithEmailController());
//     var mediaQuery = MediaQuery.of(context).size;
//     var verticalSpaceBetween = mediaQuery.height * 0.04;
//     return MaterialApp(
//       home: Scaffold(
//         body: SingleChildScrollView(
//           child: Center(
//             child: Form(
//               key: loginScreenFormKey,
//               child: Column(
//                 children: [
//                   SizedBox(height: mediaQuery.height * 0.1),
//                   // Image.asset(ImageAssets.getGabsLogoPng),
//                   Image.asset(
//                     ImageAssets.getgabsLogoPng,
//                     width: double.infinity,
//                     height: mediaQuery.height * 0.18,
//                     // height: 150,
//                     // width: mediaQuery.width * 0.45,  // 45% of screen width
//                     // height: mediaQuery.height * 0.12, // 12% of screen height
//                     fit: BoxFit.contain,
//                   ),
//                   SizedBox(height: verticalSpaceBetween),
//                   Center(
//                     child: Padding(
//                       padding: EdgeInsets.symmetric(
//                           horizontal: mediaQuery.width * 0.1),
//                       child: const AutoSizeText(
//                         'Experience the power of WhatsApp API',
//                         textAlign: TextAlign.center, // 👈 important
//                         style: TextStyle(
//                             fontSize: 18.0, fontWeight: FontWeight.w700),
//                       ),
//                     ),
//                   ),
//                   SizedBox(height: mediaQuery.height * 0.06),
//                   Padding(
//                     padding: EdgeInsets.symmetric(
//                         horizontal: MediaQuery.of(context).size.width * 0.1),
//                     child: TextFormField(
//                       controller: controller.emailController.value,
//                       keyboardType: TextInputType.emailAddress,
//                       focusNode: controller.emailFocusNode,
//                       onTapOutside: (event) {
//                         FocusScope.of(context).unfocus();
//                       },
//                       onFieldSubmitted: (value) {
//                         PredefiendLogicesUtils.fieldFocusChange(
//                             context,
//                             controller.emailFocusNode,
//                             controller.passwordFocusNodeo);
//                       },
//                       validator: (String? value) {
//                         if (value == null || value.isEmpty) {
//                           return "This field can't be empty";
//                         } 
//                         // else if (!value.isValidEmail) {
//                         //   return "Please enter valid email";
//                         // }
//                         return null;
//                       },
//                       decoration: customInputDecoration(
//                           hintText: 'Enter Username Or Email Id'),
//                     ),
//                   ),
//                   SizedBox(
//                     height: mediaQuery.height * 0.03,
//                   ),
//                   Padding(
//                     padding: EdgeInsets.symmetric(
//                         horizontal: MediaQuery.of(context).size.width * 0.1),
//                     child: ValueListenableBuilder(
//                       valueListenable: controller.obscurePassword,
//                       builder:
//                           (BuildContext context, dynamic value, Widget? child) {
//                         return TextFormField(
//                           controller: controller.passwordController.value,
//                           focusNode: controller.passwordFocusNodeo,
//                           onTapOutside: (event) {
//                             FocusScope.of(context).unfocus();
//                           },
//                           onFieldSubmitted: (value) {
//                             // Utils.fieldFocusChange(context, authController.emailFocusNode.value, authController.passwordFocusNodeo.value);
//                           },
//                           validator: (value) {
//                             if (value == null || value.isEmpty) {
//                               return "This field can't be empty";
//                             }
//                             return null;
//                           },
//                           obscureText: controller.obscurePassword.value,
//                           decoration: customInputDecoration(
//                             hintText: 'Enter Password',
//                             suffixIcon: IconButton(
//                               icon: Icon(
//                                 controller.obscurePassword.value
//                                     ? Icons.visibility_off
//                                     : Icons.visibility,
//                               ),
//                               onPressed: () {
//                                 controller.obscurePassword.value =
//                                     !controller.obscurePassword.value;
//                               },
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                   // SizedBox(
//                   //   height: mediaQuery.height * 0.001,
//                   // ),
//                   // Container(
//                   //   // width: double.infinity,
//                   //   alignment: const Alignment(-0.7, 0.0),
//                   //   child: TextButton(
//                   //     onPressed: () {
//                   //       // Get.to(() => const ForgetPasswordPage());
//                   //       // Get.toNamed(AppRoute.forgetPasswordScreen);
//                   //     },
//                   //     child: const Text(
//                   //       'Forgot Password?',
//                   //       style: TextStyle(
//                   //         color: AppTheme.authButtonColor,
//                   //         fontSize: 16,
//                   //       ),
//                   //     ),
//                   //   ),
//                   // ),
//                   SizedBox(height: mediaQuery.height * 0.045),
//                   ReusableWidgets.authButton(
//                       name: 'Login',
//                       onPressed: () {
//                         // Get.toNamed(AppRoute.dashboard);
//                         // loginWithEmailController.loignApi();
//                         if (loginScreenFormKey.currentState!.validate()) {
//                           controller.loignApi();
//                         } else {}
//                       },
//                       mediaQuery: mediaQuery),
//                   SizedBox(height: mediaQuery.height * 0.30),
//                   Padding(
//                     padding: EdgeInsets.symmetric(
//                         horizontal: mediaQuery.width * 0.1),
//                     child: const AutoSizeText(
//                       'By continuing, you agree to our',
//                       // textAlign: TextAlign.center,
//                       style: TextStyle(
//                         fontSize: 16.0,
//                       ),
//                     ),
//                   ),
//                   Padding(
//                     padding: EdgeInsets.symmetric(
//                         horizontal: mediaQuery.width * 0.1),
//                     child: const AutoSizeText(
//                       'Term of Use & Privacy Policy',
//                       // textAlign: TextAlign.center,
//                       style: TextStyle(
//                           fontSize: 16.0, fontWeight: FontWeight.w500),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   InputDecoration customInputDecoration({
//     required String hintText,
//     Color fillColor = Colors.white,
//     Color focusedBorderColor = AppTheme.boarderColor,
//     Color enabledBorderColor = AppTheme.primaryBoarderColor,
//     double borderRadius = 25.0,
//     double borderWidth = 2.0,
//     Widget? suffixIcon,
//   }) {
//     return InputDecoration(
//       hintText: hintText,
//       fillColor: fillColor,
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(borderRadius),
//         borderSide: BorderSide(
//           color: focusedBorderColor,
//         ),
//       ),
//       enabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(borderRadius),
//         borderSide: BorderSide(
//           color: enabledBorderColor,
//           width: borderWidth,
//         ),
//       ),
//       suffixIcon: suffixIcon,
//     );
//   }
// }


/*
class LoginWithEmailScreen extends GetView<LoginWithEmailController> {
  const LoginWithEmailScreen({super.key});
  // var  loginWithEmailController = Get.put(LoginWithEmailController);
  @override
  Widget build(BuildContext context) {
    var mediaQuery = MediaQuery.of(context).size;
    var verticalSpaceBetween = mediaQuery.height * 0.04;
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(
            child: Column(
              children: [
                SizedBox(height: mediaQuery.height * 0.1),
                // SvgPicture.asset(ImageAssets.getGabsLogo),
                Image.asset(ImageAssets.getGabsLogoPng),
                SizedBox(height: verticalSpaceBetween),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: mediaQuery.width * 0.1),
                  child: const AutoSizeText(
                    'Experience the power of WhatsApp API',
                    // textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(height: mediaQuery.height * 0.06),

                // Container(
                //   margin: EdgeInsets.symmetric(
                //       horizontal: MediaQuery.of(context).size.width * 0.1),
                //   padding: const EdgeInsets.symmetric(
                //       vertical: 0.0, horizontal: 10.0),
                //   decoration: BoxDecoration(
                //     borderRadius: BorderRadius.circular(38.0),
                //     border: Border.all(color: Colors.grey),
                //   ),
                //   child:
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.1),
                  child: TextFormField(
                    controller: controller.emailController.value,
                    keyboardType: TextInputType.emailAddress,
                    focusNode: controller.emailFocusNode,
                    onFieldSubmitted: (value) {
                      // PredefiendLogicesUtils.fieldFocusChange(
                      //     context,
                      //     controller.emailFocusNode,
                      //     controller.passwordFocusNodeo);
                    },
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return "This field can't be empty";
                      }
                      //else if (!value.isValidEmail) {
                      //   return "Please enter valid email";
                      // }
                      return null;
                    },
                    // decoration: InputDecoration(
                    //   border: InputBorder.none,
                    //   hintText: "Enter Username Or Email Id",
                    //   // labelText: "Email",
                    //   labelStyle: TextStyle(color: Colors.grey),
                    //   hintStyle: TextStyle(color: Colors.grey),
                    //   focusedBorder: OutlineInputBorder(
                    //     borderSide: BorderSide(
                    //       color: controller.isFocused.value
                    //           ? Colors.red
                    //           : Colors.grey,
                    //       width: 2.0,
                    //     ),
                    //     borderRadius: BorderRadius.circular(38.0),
                    //   ),
                    // ),
                    decoration: InputDecoration(
                      hintText: "Enter Username Or Email Id",
                      fillColor: Colors.white,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide(
                          color: Color(0xff77FFAA),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide(
                          color: Colors.grey,
                          width: 2.0,
                        ),
                      ),
                    ),
                  ),
                ),
                // ),
                SizedBox(
                  height: mediaQuery.height * 0.03,
                ),
                // Container(
                //   margin: EdgeInsets.symmetric(
                //       horizontal: MediaQuery.of(context).size.width * 0.1),
                //   padding: const EdgeInsets.symmetric(
                //       vertical: 0.0, horizontal: 10.0),
                //   decoration: BoxDecoration(
                //     borderRadius: BorderRadius.circular(38.0),
                //     border: Border.all(color: Colors.grey),
                //   ),
                //   child:

                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.1),
                  child: ValueListenableBuilder(
                    valueListenable: controller.obscurePassword,
                    builder:
                        (BuildContext context, dynamic value, Widget? child) {
                      return TextFormField(
                        // controller: passwordController,
                        // controller: controller.passwordController.value,
                        // focusNode: controller.passwordFocusNodeo,
                        onFieldSubmitted: (value) {
                          // Utils.fieldFocusChange(context, authController.emailFocusNode.value, authController.passwordFocusNodeo.value);
                        },
                        // obscureText: controller.obscurePassword.value,
                        decoration: InputDecoration(
                          hintText: "Enter Password",
                          fillColor: Colors.white,
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25.0),
                            borderSide: BorderSide(
                              color: Color(0xff77FFAA),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25.0),
                            borderSide: BorderSide(
                              color: Colors.grey,
                              width: 2.0,
                            ),
                          ),
                        ),
                      );
                    },
                    // ),
                  ),
                ),
                SizedBox(
                  height: mediaQuery.height * 0.001,
                ),
                Container(
                  // width: double.infinity,
                  alignment: const Alignment(-0.7, 0.0),
                  child: TextButton(
                    onPressed: () {
                      // Get.to(() => const ForgetPasswordPage());
                      // Get.toNamed(AppRoute.forgetPasswordScreen);
                    },
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: AppTheme.authButtonColor,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: mediaQuery.height * 0.045),
                ReusableWidgets.authButton(
                    name: 'Login', onPressed: () {}, mediaQuery: mediaQuery),
                SizedBox(height: mediaQuery.height * 0.30),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: mediaQuery.width * 0.1),
                  child: const AutoSizeText(
                    'By continuing, you agree to our',
                    // textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16.0,
                    ),
                  ),
                ),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: mediaQuery.width * 0.1),
                  child: const AutoSizeText(
                    'Term of Use & Privacy Policy',
                    // textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

*/