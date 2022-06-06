class Mesa
{
  int _numero = 0;
  int _status = 0; // 0 - Fechada (cor branca) || 1 - Aberta (cor verde)
  num _total = 0;
  String _identificador = ""; //M + (NUMERO DA MESA) + D + (DATA) + H + (HORA DE ABERTURA DA MESA)

  Mesa.fromJson(Map <dynamic, dynamic> json)
  {
    _numero = json['numero'];
    _status = json['status'];
    _total = json['total'];
    _identificador = json['identificador'];
  }

  Map<String, dynamic> toJson()
  {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['numero'] = this._numero;
    data['status'] = this._status;
    data['total'] = this._total;
    data['identificador'] = this._identificador;
    return data;
  }

  Mesa(){}

  int get status => _status;

  set status(int value) {
    _status = value;
  }

  int get numero => _numero;

  set numero(int value) {
    _numero = value;
  }

  num get total => _total;

  set total(num value) {
    _total = value;
  }

  String get identificador => _identificador;

  set identificador(String value) {
    _identificador = value;
  }
}