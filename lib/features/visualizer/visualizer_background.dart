class VisualizerBackground {
  const VisualizerBackground({
    required this.id,
    required this.name,
    required this.asset,
  });

  final String id;
  final String name;
  final String asset;

  static const catalogVersion = 2;

  // Stable IDs keep saved selections independent of display order or filename.
  static const presets = [
    VisualizerBackground(
      id: 'fumic',
      name: 'Fumic — Feel the Music',
      asset: 'icons/viz_bg1.jpg',
    ),
    VisualizerBackground(
      id: 'tanjiro',
      name: 'Tanjiro',
      asset: 'icons/viz_bg2.jpg',
    ),
    VisualizerBackground(
      id: 'magical-night',
      name: 'Magical Night',
      asset: 'icons/viz_bg3.jpg',
    ),
    VisualizerBackground(
      id: 'fullmoon-shrine',
      name: 'Fullmoon Shrine',
      asset: 'icons/viz_bg4.jpg',
    ),
    VisualizerBackground(
      id: 'swordmaster',
      name: 'Swordmaster',
      asset: 'icons/viz_bg5.jpg',
    ),
    VisualizerBackground(
      id: 'night-girl',
      name: 'Night Girl',
      asset: 'icons/viz_bg6.jpg',
    ),
    VisualizerBackground(
      id: 'sakura-night',
      name: 'Sakura Night',
      asset: 'icons/backgrounds/neon_sakura.png',
    ),
    VisualizerBackground(
      id: 'samurai-night',
      name: 'Samurai Night',
      asset: 'icons/backgrounds/neon_samurai.png',
    ),
    VisualizerBackground(
      id: 'matrix-rain',
      name: 'Matrix Rain',
      asset: 'icons/backgrounds/matrix_rain.png',
    ),
  ];

  static int migrateLegacyIndex(int index) {
    if (index >= 0 && index <= 4) return index + 1;
    if (index >= 6 && index < presets.length) return index;
    return 0; // Anime Sky was removed; use the new default instead.
  }
}
