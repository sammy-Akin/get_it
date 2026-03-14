import 'product_model.dart';

class CartItem {
  final ProductModel product;
  int quantity;

  CartItem({required this.product, required this.quantity});

  double get totalPrice => product.price * quantity;
}

class CartModel {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => Map.unmodifiable(_items);

  List<CartItem> get itemList => _items.values.toList();

  int get totalItems =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal =>
      _items.values.fold(0, (sum, item) => sum + item.totalPrice);

  double get deliveryFee => _items.isEmpty ? 0 : 300;

  double get total => subtotal + deliveryFee;

  // Group items by shop
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

  void deleteItem(String productId) {
    _items.remove(productId);
  }

  void clear() {
    _items.clear();
  }

  int getQuantity(String productId) {
    return _items[productId]?.quantity ?? 0;
  }

  bool contains(String productId) => _items.containsKey(productId);
}
