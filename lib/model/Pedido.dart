class Pedido{

  int _id_pedido = 0;
  int _tipo = 0; // 0 - Balcao | 1 - Entrega
  String _data = "";
  num _total = 0;
  String _identificador = "";
  int _pagamento = 0; //0 - DINHEIR0 | 1 - CARTAO | 2 - PIX
  String _nome_cliente = "";
  String _celular_cliente = "";
  String _endereco_cliente = "";
  String _obs = "";

  Pedido.fromJson(Map <dynamic, dynamic> json)
  {
    _id_pedido = json['id'];
    _tipo = json['tipo'];
    _data = json['data'];
    _total = json['total'];
    _identificador = json['identificador'];
    _pagamento = json['pagamento'];
    _nome_cliente = json['nome_cliente'];
    _celular_cliente = json['celular_cliente'];
    _endereco_cliente = json['endereco_cliente'];
    _obs = json['obs'];
  }

  Map<String, dynamic> toJson()
  {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this._id_pedido;
    data['tipo'] = this._tipo;
    data['data'] = this._data;
    data['total'] = this._total;
    data['identificador'] = this._identificador;
    data['pagamento'] = this._pagamento;
    data['nome_cliente'] = this._nome_cliente;
    data['celular_cliente'] = this._celular_cliente;
    data['endereco_cliente'] = this._endereco_cliente;
    data['obs'] = this._obs;
    return data;
  }



  Pedido();

  String get endereco_cliente => _endereco_cliente;

  set endereco_cliente(String value) {
    _endereco_cliente = value;
  }

  String get nome_cliente => _nome_cliente;

  set nome_cliente(String value) {
    _nome_cliente = value;
  }

  int get pagamento => _pagamento;

  set pagamento(int value) {
    _pagamento = value;
  }

  String get identificador => _identificador;

  set identificador(String value) {
    _identificador = value;
  }

  num get total => _total;

  set total(num value) {
    _total = value;
  }

  String get data => _data;

  set data(String value) {
    _data = value;
  }

  int get tipo => _tipo;

  set tipo(int value) {
    _tipo = value;
  }

  int get id_pedido => _id_pedido;

  set id_pedido(int value) {
    _id_pedido = value;
  }

  String get celular_cliente => _celular_cliente;

  set celular_cliente(String value) {
    _celular_cliente = value;
  }

  String get obs => _obs;

  set obs(String value) {
    _obs = value;
  }
}