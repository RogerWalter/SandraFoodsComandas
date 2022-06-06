class Entrega{

  String _cliente = "";
  num _total = 0;
  num _taxa = 0;
  int _pagamento = 0;

  Entrega.fromJson(Map <dynamic, dynamic> json)
  {
    _cliente = json['cliente'];
    _total = json['total'];
    _taxa = json['taxa'];
    _pagamento = json['pagamento'];
  }

  Map<String, dynamic> toJson()
  {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['cliente'] = this._cliente;
    data['total'] = this._total;
    data['taxa'] = this._taxa;
    data['pagamento'] = this._pagamento;
    return data;
  }
  Entrega();

  int get pagamento => _pagamento;

  set pagamento(int value) {
    _pagamento = value;
  }

  num get taxa => _taxa;

  set taxa(num value) {
    _taxa = value;
  }

  num get total => _total;

  set total(num value) {
    _total = value;
  }

  String get cliente => _cliente;

  set cliente(String value) {
    _cliente = value;
  }
}

