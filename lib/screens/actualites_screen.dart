import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/actualite_provider.dart';
import '../models/blog_post.dart';
import '../theme.dart';
import 'actualite_details_screen.dart';
import 'dashboard_home_screen.dart';
import '../widgets/bottom_navigation_bar.dart';

class ActualitesScreen extends StatefulWidget {
  const ActualitesScreen({super.key});

  @override
  State<ActualitesScreen> createState() => _ActualitesScreenState();
}

class _ActualitesScreenState extends State<ActualitesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('[ActualitesScreen] Initializing actualites screen');
    _tabController = TabController(length: 3, vsync: this);

    // Initialize the provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('[ActualitesScreen] Initializing ActualiteProvider');
      Provider.of<ActualiteProvider>(context, listen: false).initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationScaffoldWrapper(
      currentIndex: 3, // Actualites tab index
      onTap: (index) {},
      child: Consumer<ActualiteProvider>(
        builder: (context, actualiteProvider, child) {
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                color: LightModeColors.lightSurfaceVariant,
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    _buildHeader(),
                    _buildTabBar(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildActualiteTab('Actualités produits', actualiteProvider),
                          _buildActualiteTab('Actualités scientifiques', actualiteProvider),
                          _buildActualiteTab('Vie de l\'entreprise - evenements', actualiteProvider),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            LightModeColors.novoPharmaBlue,
            LightModeColors.novoPharmaBlue.withValues(alpha: 0.8),
            LightModeColors.lightSecondary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: LightModeColors.novoPharmaBlue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Main content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: LightModeColors.lightOnPrimary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: LightModeColors.lightOnPrimary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.article_rounded,
                      color: LightModeColors.lightOnPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Actualités',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: LightModeColors.lightOnPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Restez informé des dernières actualités',
                          style: TextStyle(
                            fontSize: 14,
                            color: LightModeColors.lightOnPrimary.withOpacity(0.7), // 70% opacity of white
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: LightModeColors.lightOnPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: LightModeColors.lightOnPrimary.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: LightModeColors.lightOnPrimaryContainer),
                  onChanged: (value) {
                    Provider.of<ActualiteProvider>(
                      context,
                      listen: false,
                    ).searchActualites(value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Rechercher une actualité...',
                    hintStyle: TextStyle(
                      color: LightModeColors.lightOnPrimaryContainer.withOpacity(0.7), // 70% opacity of white
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: LightModeColors.lightOnPrimaryContainer.withOpacity(0.8), // 80% opacity of white
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LightModeColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: LightModeColors.lightSurfaceVariant.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: TabBar(
          controller: _tabController,
          labelColor: LightModeColors.lightOnPrimary,
          unselectedLabelColor: LightModeColors.lightError,
          indicator: BoxDecoration(
            color: LightModeColors.lightError,
            borderRadius: BorderRadius.circular(20),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          tabs: const [
            Tab(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Actualités\nProduits',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Tab(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Actualités\nScientifiques',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Tab(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Vie de l\'entreprise\nÉvénements',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActualiteTab(String category, ActualiteProvider provider) {
    print('[ActualitesScreen] Building tab for category: $category');
    print(
      '[ActualitesScreen] Provider state - loading: ${provider.isLoading}, hasError: ${provider.hasError}',
    );

    if (provider.isLoading) {
      print('[ActualitesScreen] Showing loading indicator');
      return const Center(
        child: CircularProgressIndicator(
          color: LightModeColors.lightPrimary,
        ),
      );
    }

    if (provider.hasError) {
      print('[ActualitesScreen] Showing error state: ${provider.error}');
      return _buildErrorState(provider);
    }

    final actualites = provider.getActualitesByCategory(category);
    print(
      '[ActualitesScreen] Got ${actualites.length} actualites for category $category',
    );

    if (actualites.isEmpty) {
      print(
        '[ActualitesScreen] Showing empty state for category $category',
      );
      return _buildEmptyState(category);
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      color: LightModeColors.lightPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: actualites.length,
        itemBuilder: (context, index) {
          return _buildActualiteCard(actualites[index]);
        },
      ),
    );
  }

  Widget _buildActualiteCard(BlogPost actualite) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: LightModeColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LightModeColors.lightOnPrimary.withOpacity(0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: LightModeColors.lightSurfaceVariant.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ActualiteDetailsScreen(actualite: actualite),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section
              if (actualite.coverImageUrl != null &&
                  actualite.coverImageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          LightModeColors.lightPrimary.withOpacity(0.1),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: actualite.coverImageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: LightModeColors.lightSurfaceVariant,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: LightModeColors.lightPrimary,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: LightModeColors.lightSurfaceVariant,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: LightModeColors.dashboardTextTertiary,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),

              // Content Section
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            LightModeColors.success.withOpacity(
                              0.1,
                            ),
                            LightModeColors.success.withOpacity(
                              0.05,
                            ),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: LightModeColors.success.withOpacity(
                            0.2,
                          ),
                        ),
                      ),
                      child: Text(
                        actualite.actualiteCategory ?? 'Actualité',
                        style: const TextStyle(
                          color: LightModeColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Title
                    Text(
                      actualite.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: LightModeColors.dashboardTextPrimary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Excerpt
                    if (actualite.excerpt != null &&
                        actualite.excerpt!.isNotEmpty)
                      Text(
                        actualite.excerpt!,
                        style: TextStyle(
                          fontSize: 14,
                          color: LightModeColors.dashboardTextSecondary,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const SizedBox(height: 16),

                    // Action buttons - only show if media is available
                    _buildActionButtonsSection(actualite),
                    // Meta Information
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: LightModeColors.warning.withOpacity(
                              0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.person_outline,
                            size: 14,
                            color: LightModeColors.warning,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          actualite.author ?? 'Admin',
                          style: const TextStyle(
                            fontSize: 12,
                            color: LightModeColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: LightModeColors.lightSurfaceVariant.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: LightModeColors.dashboardTextSecondary,
                          )
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(actualite.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: LightModeColors.dashboardTextSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(ActualiteProvider provider) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: LightModeColors.lightSurface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: LightModeColors.lightSurfaceVariant.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: LightModeColors.lightError.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: LightModeColors.lightError,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Oups ! Une erreur s\'est produite',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: LightModeColors.dashboardTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Impossible de charger les actualités.\nVeuillez réessayer.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: LightModeColors.dashboardTextSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: provider.refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LightModeColors.lightPrimary,
                foregroundColor: LightModeColors.lightSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String category) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: LightModeColors.lightSurface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: LightModeColors.lightSurfaceVariant.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: LightModeColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.article_outlined,
                size: 48,
                color: LightModeColors.warning,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune actualité disponible',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: LightModeColors.dashboardTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Il n\'y a pas encore d\'actualités\ndans la catégorie "$category".',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: LightModeColors.dashboardTextSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                Provider.of<ActualiteProvider>(
                  context,
                  listen: false,
                ).refresh();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Actualiser'),
              style: OutlinedButton.styleFrom(
                foregroundColor: LightModeColors.warning,
                side: const BorderSide(color: LightModeColors.warning),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m';
      }
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}j';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildActionButtonsSection(BlogPost actualite) {
    // Collect available action buttons
    List<Widget> topRowButtons = [];

    // Video button (first priority - top row)
    if (actualite.hasVideo) {
      topRowButtons.add(
        Expanded(
          child: _buildActionButton(
            'Vidéo explicative',
            Icons.play_circle_outline,
            () => _showVideoDialog(actualite),
          ),
        ),
      );
    }

    // If no buttons available, return empty container
    if (topRowButtons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Row(children: topRowButtons),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: LightModeColors.lightError,
        side: BorderSide(color: LightModeColors.lightError),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showVideoDialog(BlogPost actualite) async {
    if (!actualite.hasVideo) {
      _showSnackBar('Aucune vidéo disponible pour cette actualité');
      return;
    }

    final videoUrl = actualite.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) {
      _showSnackBar('URL de la vidéo non disponible');
      return;
    }

    try {
      final Uri url = Uri.parse(videoUrl);
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        // Try with inAppBrowserView as fallback
        await launchUrl(url, mode: LaunchMode.inAppBrowserView);
      }
    } catch (e) {
      print('Error launching video: $e');
      print('Video URL: $videoUrl');
      _showSnackBar('Erreur lors de l\'ouverture de la vidéo');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: LightModeColors.novoPharmaBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
