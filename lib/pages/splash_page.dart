import 'package:flutter/material.dart';
import 'auth_page.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final minButtonHeight = 48.0;
        final maxButtonHeight = 70.0;
        final buttonHeight = (height * 0.07).clamp(minButtonHeight, maxButtonHeight);
        final minLogoHeight = 48.0;
        final maxLogoHeight = 120.0;
        final logoHeight = (height * 0.08).clamp(minLogoHeight, maxLogoHeight);
        final horizontalPadding = (width * 0.06).clamp(16.0, 64.0);
        final cardWidth = (width * 0.22).clamp(80.0, 220.0);
        final cardHeight = (height * 0.11).clamp(48.0, 120.0);
        final stackHeight = (height * 0.25).clamp(160.0, 320.0);
        final stackTopOffset = (height * 0.06).clamp(12.0, 48.0);
        final stackTopOffset2 = (height * 0.04).clamp(8.0, 32.0);
        final stackTopOffset3 = (height * 0.12).clamp(24.0, 64.0);
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: height - MediaQuery.of(context).padding.vertical),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset('assets/icons/auth_logo.png', height: logoHeight),
                          ],
                        ),
                        SizedBox(height: height * 0.05),
                        SizedBox(
                          height: stackHeight,
                          width: width,
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                top: stackTopOffset,
                                left: width * 0.1,
                                child: stockCard(
                                  'AAPL',
                                  '+108,68%',
                                  'assets/logos/apple.png',
                                  Colors.blue,
                                  cardWidth,
                                  cardHeight,
                                  isDark,
                                ),
                              ),
                              Positioned(
                                top: stackTopOffset2,
                                right: width * 0.1,
                                child: stockCard(
                                  'UNVR',
                                  '+82,34%',
                                  'assets/logos/uni.png',
                                  Colors.orange,
                                  cardWidth,
                                  cardHeight,
                                  isDark,
                                ),
                              ),
                              Positioned(
                                top: 0,
                                child: stockCard(
                                  'TSLA',
                                  '-54,49%',
                                  'assets/logos/tesla.png',
                                  Colors.red,
                                  cardWidth,
                                  cardHeight,
                                  isDark,
                                ),
                              ),
                              Positioned(
                                top: stackTopOffset3,
                                child: stockCard(
                                  'BTC',
                                  '+198,39%',
                                  'assets/logos/bitcoin.png',
                                  Colors.green,
                                  cardWidth,
                                  cardHeight,
                                  isDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: height * 0.05),
                        Text(
                          'Stock Stream',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: (width * 0.06).clamp(20.0, 36.0),
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Track stocks in real-time with live streaming ticker.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: (width * 0.035).clamp(14.0, 22.0),
                            color: isDark ? const Color(0xFFC2C2C2) : Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: height * 0.05),
                        SizedBox(
                          width: double.infinity,
                          height: buttonHeight,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (context) => const AuthPage()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E9712),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text(
                              "Let's Get Started",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ),
                        SizedBox(height: height * 0.03),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget stockCard(
      String ticker,
      String change,
      String iconPath,
      Color color,
      double cardWidth,
      double cardHeight,
      bool isDark,
      ) {
    // Use white color filter for Apple & Tesla if dark mode
    final bool shouldBeWhite = isDark && (iconPath.contains('apple') || iconPath.contains('tesla'));

    return Container(
      width: cardWidth,
      height: cardHeight,
      padding: EdgeInsets.all(cardHeight * 0.08),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
        borderRadius: BorderRadius.circular(cardHeight * 0.15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            iconPath,
            height: cardHeight * 0.35,
            color: shouldBeWhite ? Colors.white : null,
          ),
          SizedBox(height: cardHeight * 0.04),
          Text(
            ticker,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: cardHeight * 0.11,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          Text(
            change,
            style: TextStyle(
              fontSize: cardHeight * 0.11,
              color: color
            ),
          ),
        ],
      ),
    );
  }
}
