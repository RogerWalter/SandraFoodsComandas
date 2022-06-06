class ItemMesa
{
  int _id_item = 0;
  int _id_mesa = 0;
  String _desc_item = "";
  String _obs_adici = "";
  num _valor_uni = 0;
  num _valor_tot = 0;
  int _qtd = 0;

  ItemMesa();

  ItemMesa.fromJson(Map <dynamic, dynamic> json)
  {
    _id_item = json['id'];
    _id_mesa = json['mesa'];
    _desc_item = json['desc_item'];
    _obs_adici = json['obs_adici'];
    _valor_uni = json['valor_uni'];
    _valor_tot = json['valor_tot'];
    _qtd = json['qtd'];
  }

  Map<String, dynamic> toJson()
  {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this._id_item;
    data['mesa'] = this._id_mesa;
    data['desc_item'] = this._desc_item;
    data['obs_adici'] = this._obs_adici;
    data['valor_uni'] = this._valor_uni;
    data['valor_tot'] = this._valor_tot;
    data['qtd'] = this._qtd;
    return data;
  }

  Itens(){}

  int get qtd => _qtd;

  set qtd(int value) {
    _qtd = value;
  }

  num get valor_uni => _valor_uni;

  set valor_uni(num value) {
    _valor_uni = value;
  }

  String get obs_adici => _obs_adici;

  set obs_adici(String value) {
    _obs_adici = value;
  }

  String get desc_item => _desc_item;

  set desc_item(String value) {
    _desc_item = value;
  }

  int get id_mesa => _id_mesa;

  set id_mesa(int value) {
    _id_mesa = value;
  }

  int get id_item => _id_item;

  set id_item(int value) {
    _id_item = value;
  }

  num get valor_tot => _valor_tot;

  set valor_tot(num value) {
    _valor_tot = value;
  }
}