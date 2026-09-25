import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer_model.dart';

class CustomerProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<CustomerModel> _customers = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<CustomerModel> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Firestore Collection Reference
  CollectionReference<Map<String, dynamic>> get _customerCollection =>
      _firestore.collection('customers');

  /// 1. Real-time stream to listen for Customer updates from Firestore
  void fetchCustomers() {
    _isLoading = true;
    notifyListeners();

    _customerCollection.snapshots().listen(
      (snapshot) {
        _customers = snapshot.docs.map((doc) {
          return CustomerModel.fromMap(doc.data(), doc.id);
        }).toList();
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  /// 2. Add New Customer to Firestore
  Future<bool> addCustomer(CustomerModel customer) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _customerCollection.add(customer.toMap());

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 3. Update Existing Customer Details
  Future<bool> updateCustomer(CustomerModel customer) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _customerCollection.doc(customer.id).update(customer.toMap());

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 4. Delete Customer
  Future<bool> deleteCustomer(String customerId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _customerCollection.doc(customerId).delete();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 5. Update Customer Balance (Order create hone par ya Payment receiving par)
  /// Positive amount = Udhaar / Khata barha
  /// Negative amount = Payment aai / Balance kam hua
  Future<bool> updateCustomerBalance(String customerId, double amountChange) async {
    try {
      await _customerCollection.doc(customerId).update({
        'balance': FieldValue.increment(amountChange),
      });
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}