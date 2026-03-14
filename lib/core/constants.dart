class AppConstants {
  // App Info
  static const String appName = 'Get It';
  static const String appTagline = 'Delivered to your door';

  // Delivery
  static const double deliveryFee = 300.0;
  static const double riderIncentive = 150.0;
  static const int riderAcceptTimeoutSeconds = 30;
  static const int vendorConfirmTimeoutSeconds = 120;

  // Collections (Firestore)
  static const String usersCollection = 'users';
  static const String vendorsCollection = 'vendors';
  static const String ridersCollection = 'riders';
  static const String ordersCollection = 'orders';
  static const String productsCollection = 'products';
  static const String categoriesCollection = 'categories';

  // Order Statuses
  static const String orderPending = 'pending';
  static const String orderConfirmed = 'confirmed';
  static const String orderReadyForRider = 'ready_for_rider';
  static const String orderRiderAssigned = 'rider_assigned';
  static const String orderOutForDelivery = 'out_for_delivery';
  static const String orderDelivered = 'delivered';
  static const String orderCancelled = 'cancelled';

  // Vendor Order Statuses
  static const String vendorPending = 'pending';
  static const String vendorConfirmed = 'confirmed';
  static const String vendorReady = 'ready';
  static const String vendorPickedUp = 'picked_up';

  // Rider Statuses
  static const String riderOnline = 'online';
  static const String riderOffline = 'offline';
  static const String riderBusy = 'busy';

  // Routes
  static const String splashRoute = '/';
  static const String onboardingRoute = '/onboarding';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String homeRoute = '/home';
  static const String productRoute = '/product';
  static const String shopRoute = '/shop';
  static const String cartRoute = '/cart';
  static const String checkoutRoute = '/checkout';
  static const String orderTrackingRoute = '/order-tracking';
  static const String orderHistoryRoute = '/order-history';
  static const String profileRoute = '/profile';
}
