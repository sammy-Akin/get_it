import 'package:flutter/material.dart';
import '../models/cart_model.dart';
import '../models/product_model.dart';

class CartProvider extends ChangeNotifier {
  final CartModel _cart = CartModel();

  CartModel get cart => _cart;

  int get totalItems => _cart.totalItems;
  double get subtotal => _cart.subtotal;
  double get serviceCharge => _cart.serviceCharge;
  double get deliveryFee => _cart.deliveryFee;
  double get riderIncentive => _cart.riderIncentive;
  double get total => _cart.total;

  void addItem(ProductModel product) {
    _cart.addItem(product);
    notifyListeners();
  }

  void removeItem(String productId) {
    _cart.removeItem(productId);
    notifyListeners();
  }

  void deleteItem(String productId) {
    _cart.deleteItem(productId);
    notifyListeners();
  }

  void clear() {
    _cart.clear();
    notifyListeners();
  }

  int getQuantity(String productId) => _cart.getQuantity(productId);
  bool contains(String productId) => _cart.contains(productId);
}
