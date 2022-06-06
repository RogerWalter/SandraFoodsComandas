class Parametro{

  String? _nome_garcom = "";
  int _qtd_mesas = 0;
  int _qtd_colunas = 1;
  int _qtd_vias_imprimir = 1;
  String? _ip_impressora = "";

  Parametro.fromJson(Map <dynamic, dynamic> json)
  {
    _qtd_mesas = json['qtd_mesas'];
    _qtd_vias_imprimir = json['qtd_vias_imprimir'];
    _ip_impressora = json['ip_impressora'];
  }

  Map<String, dynamic> toJson()
  {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['qtd_mesas'] = this._qtd_mesas;
    data['qtd_vias_imprimir'] = this._qtd_vias_imprimir;
    data['ip_impressora'] = this._ip_impressora;
    return data;
  }

  Parametro();


  String get nome_garcom => _nome_garcom.toString();

  set nome_garcom(String value) {
    _nome_garcom = value;
  }

  int get qtd_vias_imprimir => _qtd_vias_imprimir;

  set qtd_vias_imprimir(int value) {
    _qtd_vias_imprimir = value;
  }

  int get qtd_colunas => _qtd_colunas;

  set qtd_colunas(int value) {
    _qtd_colunas = value;
  }

  int get qtd_mesas => _qtd_mesas;

  set qtd_mesas(int value) {
    _qtd_mesas = value;
  }

  String get ip_impressora => _ip_impressora.toString();

  set ip_impressora(String value) {
    _ip_impressora = value;
  }
}