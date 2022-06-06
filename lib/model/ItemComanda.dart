class ItemComanda{
  String _id = "";
  int _mesa = 0;
  String _data = "";
  String _nome = "";
  num _valor = 0;
  int _qtd = 0;

  ItemComanda.fromJson(Map <dynamic, dynamic> json)
  {
    _id = json['id'];
    _mesa = json['mesa'];
    _data = json['data'];
    _nome = json['nome'];
    _valor = json['valor'];
    _qtd = json['qtd'];
  }

  Map<String, dynamic> toJson()
  {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this._id;
    data['mesa'] = this._mesa;
    data['data'] = this._data;
    data['nome'] = this._nome;
    data['valor'] = this._valor;
    data['qtd'] = this._qtd;
    return data;
  }

  ItemComanda();

  int get qtd => _qtd;

  set qtd(int value) {
    _qtd = value;
  }

  num get valor => _valor;

  set valor(num value) {
    _valor = value;
  }

  String get nome => _nome;

  set nome(String value) {
    _nome = value;
  }

  String get data => _data;

  set data(String value) {
    _data = value;
  }

  int get mesa => _mesa;

  set mesa(int value) {
    _mesa = value;
  }

  String get id => _id;

  set id(String value) {
    _id = value;
  }
}