class NearbyDevice {
  final String endpointId;
  String name;
  bool isConnected;
  bool isConnecting;
  bool isAvailable;

  NearbyDevice({
    required this.endpointId,
    required this.name,
    this.isConnected = false,
    this.isConnecting = false,
    this.isAvailable = true,
  });
}
