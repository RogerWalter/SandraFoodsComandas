class Comanda{

  String _id = "";
  int _mesa = 0;
  String _data = "";
  num _total = 0;
  int _pagamento = -1;
  int _fechamento = -1;

  Comanda.fromJson(Map <dynamic, dynamic> json)
  {
    _id = json['id'];
    _mesa = json['mesa'];
    _data = json['data'];
    _total = json['total'];
    _pagamento = json['pagamento'];
    _fechamento = json['fechamento'];
  }

  Map<String, dynamic> toJson()
  {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this._id;
    data['mesa'] = this._mesa;
    data['data'] = this._data;
    data['total'] = this._total;
    data['pagamento'] = this._pagamento;
    data['fechamento'] = this._fechamento;
    return data;
  }

  Comanda();

  num get total => _total;

  set total(num value) {
    _total = value;
  }

  int get mesa => _mesa;

  set mesa(int value) {
    _mesa = value;
  }

  String get id => _id;

  set id(String value) {
    _id = value;
  }

  int get pagamento => _pagamento;

  set pagamento(int value) {
    _pagamento = value;
  }

  String get data => _data;

  set data(String value) {
    _data = value;
  }

  int get fechamento => _fechamento;

  set fechamento(int value) {
    _fechamento = value;
  }
}