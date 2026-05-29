enum MediaKind { audio, video }

String mediaKindLabel(MediaKind kind) {
  return kind == MediaKind.audio ? 'AUDIO' : 'VIDEO';
}
