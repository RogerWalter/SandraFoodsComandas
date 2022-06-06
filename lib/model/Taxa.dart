class Taxa
{
  int _id = 0;
  String _bairro = "";
  num _valor = 0;

  Taxa.fromJson(Map <dynamic, dynamic> json)
  {
    _id = json['id'];
    _bairro = json['bairro'];
    _valor = json['valor'];
  }

  Map<String, dynamic> toJson()
  {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this._id;
    data['bairro'] = this._bairro;
    data['valor'] = this._valor;
    return data;
  }

  Taxa(){}

  num get valor => _valor;

  set valor(num value) {
    _valor = value;
  }

  String get bairro => _bairro;

  set bairro(String value) {
    _bairro = value;
  }

  int get id => _id;

  set id(int value) {
    _id = value;
  }
}