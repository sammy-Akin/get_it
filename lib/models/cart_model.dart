import 'product_model.dart';

class CartItem {
  final ProductModel product;
  int quantity;

  CartItem({required this.product, required this.quantity});

  double get totalPrice => product.price * quantity;
}

class CartModel {
  final Map<String, CartItem> _items = {};

  // Distance in km set externally before checkout
  double deliveryDistanceKm = 0;

  Map<String, CartItem> get items => Map.unmodifiable(_items);
  List<CartItem> get itemList => _items.values.toList();
  int get totalItems =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);
  double get subtotal =>
      _items.values.fold(0, (sum, item) => sum + item.totalPrice);

  // 3% service charge on subtotal
  double get serviceCharge =>
      double.parse((subtotal * 0.03).toStringAsFixed(2));

  double get deliveryFee => 0;

  // Distance-based picker incentive:
  // 0–0.5km  → ₦150
  // 0.5–1km  → ₦200
  // >1km     → ₦250
  double get riderIncentive {
    if (_items.isEmpty) return 0;
    if (deliveryDistanceKm <= 0.5) return 150;
    if (deliveryDistanceKm <= 1.0) return 200;
    return 250;
  }

  double get total =>
      _items.isEmpty ? 0 : subtotal + serviceCharge + riderIncentive;

  Map<String, List<CartItem>> get itemsByShop {
    final Map<String, List<CartItem>> grouped = {};
    for (final item in _items.values) {
      final shopId = item.product.shopId;
      grouped[shopId] ??= [];
      grouped[shopId]!.add(item);
    }
    return grouped;
  }

  void addItem(ProductModel product) {
    if (_items.containsKey(product.id)) {
      if (_items[product.id]!.quantity < product.stockQty) {
        _items[product.id]!.quantity++;
      }
    } else {
      _items[product.id] = CartItem(product: product, quantity: 1);
    }
  }

  void removeItem(String productId) {
    if (_items.containsKey(productId)) {
      if (_items[productId]!.quantity > 1) {
        _items[productId]!.quantity--;
      } else {
        _items.remove(productId);
      }
    }
  }

  void deleteItem(String productId) => _items.remove(productId);
  void clear() => _items.clear();
  int getQuantity(String productId) => _items[productId]?.quantity ?? 0;
  bool contains(String productId) => _items.containsKey(productId);
}
