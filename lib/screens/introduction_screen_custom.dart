import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/screens/signup_screen.dart';
import 'package:novopharma/theme.dart';
import 'package:provider/provider.dart';

class IntroductionScreenCustom extends StatelessWidget {
  const IntroductionScreenCustom({super.key});

  void _onIntroEnd(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.markIntroSeen();
    // AuthWrapper will handle navigation to LoginScreen
  }

  void _onSignup(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.markIntroSeen();

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SignupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // Page Decoration
    final pageDecoration = PageDecoration(
      footerPadding: EdgeInsets.only(top: 0.0),
      titleTextStyle: const TextStyle(fontSize: 0.0, height: 0),
      bodyTextStyle: GoogleFonts.inter(
        fontSize: 16,
        color: LightModeColors.dashboardTextSecondary,
        height: 1.6,
      ),
      bodyPadding: EdgeInsets.zero,
      pageColor: Colors.white,
      imagePadding: EdgeInsets.zero,
      contentMargin: EdgeInsets.zero,
      imageFlex: 0,
      bodyFlex: 1,
      footerFlex: 0,
      bodyAlignment: Alignment.topCenter,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: IntroductionScreen(
          globalBackgroundColor: Colors.white,
          allowImplicitScrolling: true,
          autoScrollDuration: null,
          infiniteAutoScroll: false,
          pages: [
            _buildPage(
              context,
              description:
                  "Suivi des ventes\n\nScannez ou saisissez manuellement vos ventes. Chaque vente enregistrée vous permet de gagner des points.",
              imagePath: 'assets/images/introductionScreen/image1.png',
              decoration: pageDecoration,
              isFirstBold: true,
            ),
            _buildPage(
              context,
              description:
                  "Récompenses\n\nÉchangez vos points contre des crédits Pluxee. Vos efforts ont de la valeur !",
              imagePath: 'assets/images/introductionScreen/image2.png',
              decoration: pageDecoration,
              isFirstBold: true,
            ),
            _buildPage(
              context,
              description:
                  "Objectifs\n\nStimulez vos ventes grâce à des objectifs définis régulièrement.",
              imagePath: 'assets/images/introductionScreen/image3.png',
              decoration: pageDecoration,
              isFirstBold: true,
            ),
            _buildPage(
              context,
              description:
                  "Challenges\n\nDébloquez les badges et relevez les défis. Des cadeaux vous attendent !",
              imagePath: 'assets/images/introductionScreen/image4.png',
              decoration: pageDecoration,
              isFirstBold: true,
            ),
            _buildPage(
              context,
              description:
                  "Formations\n\nApprenez. Conseillez mieux. Gagnez plus.",
              imagePath: 'assets/images/introductionScreen/image5.png',
              decoration: pageDecoration,
              isFirstBold: true,
            ),
          ],
          onDone: () => _onIntroEnd(context),
          onSkip: () => _onIntroEnd(context),
          showSkipButton: true,
          skipOrBackFlex: 0,
          nextFlex: 0,
          showBackButton: false,
          skip: Text(
            'Passer',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: LightModeColors.novoPharmaGray,
              fontSize: 16,
            ),
          ),
          next: Text(
            'Suivant',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: LightModeColors.novoPharmaBlue,
              fontSize: 16,
            ),
          ),
          done: Text(
            'Fin',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: LightModeColors.novoPharmaBlue,
              fontSize: 16,
            ),
          ),
          curve: Curves.fastLinearToSlowEaseIn,
          controlsMargin: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
          controlsPadding: const EdgeInsets.symmetric(vertical: 4),
          dotsDecorator: const DotsDecorator(
            size: Size(8.0, 8.0),
            color: Color(0xFFE5E7EB),
            activeSize: Size(20.0, 8.0),
            activeShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(25.0)),
            ),
            activeColor: LightModeColors.novoPharmaBlue,
          ),
        ),
      ),
    );
  }

  PageViewModel _buildPage(
    BuildContext context, {
    required String description,
    required String imagePath,
    required PageDecoration decoration,
    bool isFirstBold = false,
  }) {
    return PageViewModel(
      titleWidget: const SizedBox.shrink(),
      bodyWidget: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: isFirstBold
                  ? _buildRichText(description)
                  : Text(
                      description,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: LightModeColors.dashboardTextSecondary,
                        height: 1.5,
                      ),
                    ),
            ),
            const SizedBox(height: 15),
            // Larger responsive image
            Image.asset(
              imagePath,
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.height * 0.48,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _onIntroEnd(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LightModeColors.novoPharmaBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Text(
                        "Connexion",
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _onSignup(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: LightModeColors.novoPharmaBlue,
                        elevation: 0,
                        side: const BorderSide(
                          color: LightModeColors.novoPharmaBlue,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Text(
                        "S'inscrire",
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      decoration: decoration,
    );
  }

  Widget _buildRichText(String text) {
    final parts = text.split('\n');
    if (parts.length > 1) {
      return RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: GoogleFonts.inter(
            fontSize: 16,
            color: LightModeColors.dashboardTextSecondary,
            height: 1.5,
          ),
          children: [
            TextSpan(
              text: parts.first,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: LightModeColors.novoPharmaBlue,
              ),
            ),
            const TextSpan(text: '\n'),
            TextSpan(text: parts.sublist(1).join('\n')),
          ],
        ),
      );
    }

    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: LightModeColors.dashboardTextSecondary,
        height: 1.5,
      ),
    );
  }
}
