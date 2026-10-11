import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart'; // 👈 Imported url_launcher

class ServerBannerCarousel extends StatefulWidget {
  final String baseUrl;

  const ServerBannerCarousel({super.key, required this.baseUrl});

  @override
  State<ServerBannerCarousel> createState() => _ServerBannerCarouselState();
}

class _ServerBannerCarouselState extends State<ServerBannerCarousel> {
  final PageController _pageController = PageController();
  List<dynamic> _banners = [];
  bool _isLoading = true;
  int _currentPage = 0;
  Timer? _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _fetchBanners();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchBanners() async {
    try {
      String cleanBaseUrl = widget.baseUrl.trim();
      if (cleanBaseUrl.endsWith('/')) {
        cleanBaseUrl = cleanBaseUrl.substring(0, cleanBaseUrl.length - 1);
      }

      final String requestUrl = cleanBaseUrl.endsWith('/api')
          ? '$cleanBaseUrl/banners/'
          : '$cleanBaseUrl/api/banners/';

      debugPrint("🌐 Fetching Banners from: $requestUrl");

      final response = await http
          .get(Uri.parse(requestUrl))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        List<dynamic> fetchedBanners = [];
        if (data is Map<String, dynamic> && data.containsKey('banners')) {
          fetchedBanners = data['banners'] ?? [];
        } else if (data is List) {
          fetchedBanners = data;
        }

        if (mounted) {
          setState(() {
            _banners = fetchedBanners;
            _isLoading = false;
          });

          if (_banners.length > 1) {
            _startAutoSlide();
          }
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("❌ Exception in Banner API: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_pageController.hasClients && _banners.isNotEmpty) {
        _currentPage = (_currentPage + 1) % _banners.length;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // 🔗 Helper method to open action_url in web browser or external app
  Future<void> _handleBannerTap(String? actionUrl) async {
    if (actionUrl == null || actionUrl.trim().isEmpty) return;

    try {
      final Uri uri = Uri.parse(actionUrl.trim());
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("Could not launch URL: $actionUrl");
      }
    } catch (e) {
      debugPrint("Error launching URL: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 120,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF8C00), strokeWidth: 2),
        ),
      );
    }

    if (_banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SizedBox(
          height: 120,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _banners.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              final banner = _banners[index];
              final String title = banner['title'] ?? 'Announcement';
              final String description = banner['description'] ?? '';
              final String? imageUrl = banner['image_url'];
              final String? actionUrl = banner['action_url']; // 👈 Extract URL

              return GestureDetector(
                onTap: () => _handleBannerTap(actionUrl), // 👈 Handle tap
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF8C00), Color(0xFFFF5500)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    image: (imageUrl != null && imageUrl.isNotEmpty)
                        ? DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Colors.black.withOpacity(0.35),
                              BlendMode.darken,
                            ),
                          )
                        : null,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _banners.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentPage == index ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? const Color(0xFFFF8C00)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}