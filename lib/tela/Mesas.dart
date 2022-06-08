import 'package:comandas_app/model/Mesa.dart';
import 'package:comandas_app/tela/Visualizar.dart';
import 'package:comandas_app/tela/Fechar.dart';
import 'package:comandas_app/model/Parametro.dart';
import 'package:comandas_app/res/CustomColors.dart';
import 'package:comandas_app/tela/Adicionar.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/rendering.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Mesas()
  ));
}

class Mesas extends StatefulWidget {
  const Mesas({Key? key}) : super(key: key);

  @override
  _MesasState createState() => _MesasState();
}

class _MesasState extends State<Mesas> {

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _verificarParametros();
  }
  Color _corLaranjaSF = const Color(0xffff6900);
  Color _corMarromSF = const Color(0xff3d2314);

  Parametro _parametros = Parametro();
  int _parametro_qtd_mesas_antigo = 0;
  TextEditingController _controllerNome = TextEditingController();
  TextEditingController _controllerQtdMesas = TextEditingController();
  TextEditingController _controllerQtdColunas = TextEditingController();
  TextEditingController _controllerQtdVias = TextEditingController();
  TextEditingController _controllerIpImp = TextEditingController();
  bool _visibility = false;

  int _parametro_tipo_adicionar = -1; //0 = MESA | 1 = ENTREGA | 2 = BALCÃO

  final List <Mesa> _listaMesas = [];

  _carregaDadosMesas(String _nome, int _qtd){
    setState(() {
      build(context);
      _parametros.nome_garcom = _nome;
      _parametros.qtd_colunas = _qtd;
      _visibility = true;
    });
  }

  _salvarParametros(int _parametro_primeiro_acesso) async{
    final prefs = await SharedPreferences.getInstance();
    prefs.setString("nome", _parametros.nome_garcom);
    prefs.setInt("coluna", _parametros.qtd_colunas);

    final json = _parametros.toJson();
    final ref = FirebaseDatabase.instance.ref("parametros/");
    await ref.set(json);
    if(_parametro_primeiro_acesso == 1)
      _salvarMesaFirebase(_parametros.qtd_mesas);
  }

  _verificarParametros() async{
    final ref = FirebaseDatabase.instance.ref();
    final snapshot = await ref.child("parametros").get();
    final prefs = await SharedPreferences.getInstance();
    if(prefs.getString("nome") != null && prefs.getString("nome") != "")
      {
        String nome_garcom_recuperado = prefs.getString("nome").toString();
        int qtd_colunas_recuperada = int.parse(prefs.getInt("coluna").toString());
        if (snapshot.exists) {//Ja foi acessado o app antes, já existe parametrização
          final json = snapshot.value as Map<dynamic, dynamic>;
          _parametros = Parametro.fromJson(json);
          _recupera_infos_mesas_existentes(nome_garcom_recuperado, qtd_colunas_recuperada);
        } else {//app nunca foi acessado. Necessário abrir tela para definição de parâmetros
          mostrarDialogoParametros();
        }
      }
    else
      {
        mostrarDialogoParametros();
      }
  }

  _salvarMesaFirebase(int _qtd_mesas) async{
    await Firebase.initializeApp();

    final ref = FirebaseDatabase.instance.ref();
    final snapshot = await ref.child("mesas").get();
    if (snapshot.exists) {
      _recupera_infos_mesas_existentes(_parametros.nome_garcom, _parametros.qtd_colunas);
    }
    else{
      for(int i = 1; i <=_qtd_mesas; i++ )
      {
        Mesa _mesa = Mesa();
        _mesa.numero = i;
        _mesa.status = 0;
        _mesa.total = 0;
        _mesa.identificador = "";
        final json = _mesa.toJson();
        final ref = FirebaseDatabase.instance.ref("mesas/" + i.toString());
        await ref.set(json);
      }
      _recupera_infos_mesas_existentes(_parametros.nome_garcom, _parametros.qtd_colunas);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Color(0xff3d2314),
          title: const Text('Mesas e Comandas', style: TextStyle(color: Colors.white)),
          actions: <Widget>[
            IconButton(
              icon: const Icon
                (Icons.build, color: Color(0xffff6900),),
              tooltip: 'Configurações',
              onPressed: () {
                setState(() {
                  mostrarDialogoParametros();
                });
              },
            ),
          ],
        ),
        backgroundColor: Colors.white,
        body: Stack(
            children: <Widget>[
              Visibility(
                  visible: !_visibility,
                  child: Container(
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(
                        strokeWidth: 10,
                        backgroundColor: CustomColors().corMarromSF,
                        valueColor: AlwaysStoppedAnimation<Color> (CustomColors().corLaranjaSF),
                      )
                  )
              ),

              Visibility(
                visible: _visibility,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: Padding(
                            padding:  EdgeInsets.all(4),
                            child: Container(
                              height: 40,
                              child: ElevatedButton(
                                  onPressed: (){
                                    setState(() {
                                      //abrimos a tela de adicionar itens para o balcão
                                      _parametro_tipo_adicionar = 2;
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) => Adicionar(0, _parametros.nome_garcom, _parametros.ip_impressora, _parametros.qtd_vias_imprimir, _parametro_tipo_adicionar)
                                          )
                                      );
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    elevation: 4,
                                    padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                    primary: _corMarromSF,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text("Balcão", style: TextStyle(color: _corLaranjaSF, fontSize: 16, fontWeight: FontWeight.w900),)
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding:  EdgeInsets.all(4),
                            child: Container(
                              height: 40,
                              child: ElevatedButton(
                                  onPressed: (){
                                    _parametro_tipo_adicionar = 1;
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) => Adicionar(0, _parametros.nome_garcom, _parametros.ip_impressora, _parametros.qtd_vias_imprimir, _parametro_tipo_adicionar)
                                        )
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    elevation: 4,
                                    padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                    primary: _corMarromSF,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text("Entrega", style: TextStyle(color: _corLaranjaSF, fontSize: 16, fontWeight: FontWeight.w900),)
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                    Expanded(
                      child: ScrollConfiguration(
                          behavior: ScrollBehavior(),
                          child: GlowingOverscrollIndicator(
                              axisDirection: AxisDirection.down,
                              color: _corLaranjaSF.withOpacity(0.20),
                              child: GridView.count(
                                scrollDirection: Axis.vertical,
                                shrinkWrap: true,
                                crossAxisCount: _parametros.qtd_colunas,
                                mainAxisSpacing: (16/_parametros.qtd_colunas),
                                crossAxisSpacing: (16/_parametros.qtd_colunas),
                                children: List.generate(_listaMesas.length, (index) {
                                  return Card(
                                      elevation: 4,
                                      child: InkWell(
                                          splashColor: _corLaranjaSF.withOpacity(0.20),
                                          onTap: (){
                                            mostrarDialogoMesa(index + 1, _listaMesas[index].total, _listaMesas[index].identificador);
                                          },
                                          child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.transparent,
                                                border: Border.all(
                                                    color: (_listaMesas.length > 0 && _listaMesas[index].status == 1) ? _corLaranjaSF : _corMarromSF,
                                                    width: 6
                                                ),
                                                borderRadius: BorderRadius.all(Radius.circular(5)),
                                              ),
                                              margin: EdgeInsets.all(8),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                children: <Widget>[
                                                  Text(
                                                    "Mesa " + _listaMesas[index].numero.toString(),
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: _corMarromSF,
                                                      fontSize: (48/_parametros.qtd_colunas),
                                                    ),
                                                  ),
                                                  Text(
                                                    "Total:\n" + NumberFormat.simpleCurrency(locale: 'pt_BR').format(_listaMesas[index].total),
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                        color: Colors.deepOrange,
                                                        fontSize: (40/_parametros.qtd_colunas),
                                                        fontWeight: FontWeight.w700
                                                    ),
                                                  )
                                                ],
                                              )
                                          )
                                      )
                                  );
                                }),
                              ),
                          )
                      )
                    )
                  ],
                )
              )
            ]
        )
    );
  }

  mostrarDialogoMesa(int numMesa, num total, String identificador)
  {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ScaffoldMessenger(
        child: Builder(
            builder: (context) => WillPopScope(
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  body: Dialog(
                    elevation: 6,
                    insetAnimationDuration: Duration(seconds: 1),
                    insetAnimationCurve: Curves.slowMiddle,
                    insetPadding: EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), //this right here
                    child: Container(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Padding(
                            padding:  EdgeInsets.all(4),
                            child: Text('Mesa '+ numMesa.toString(), style: TextStyle(color: Color(0xffff6900), fontSize: 28, fontWeight: FontWeight.w800),),
                          ),
                          Padding(
                            padding:  EdgeInsets.all(4),
                            child: Container(
                              height: 50,
                              width: 170,
                              child: Expanded(
                                child: ElevatedButton(
                                    onPressed: (){
                                      _parametro_tipo_adicionar = 0;
                                      Navigator.of(context).pop();
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) => Adicionar(numMesa, _parametros.nome_garcom, _parametros.ip_impressora, _parametros.qtd_vias_imprimir, _parametro_tipo_adicionar)
                                          )
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.fromLTRB(0, 0, 4, 0),
                                      primary: Color(0xff3d2314),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  child: Row(
                                    children: <Widget>[
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(4, 0, 8, 0),
                                        child: Icon(
                                          Icons.add,
                                          color: _corLaranjaSF,
                                          size: 30,
                                        ),
                                      ),
                                      Text("Adicionar Itens", style: TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.left)
                                    ],
                                  ),),
                              )
                            ),
                          ),
                          Padding(
                            padding:  EdgeInsets.all(4),
                            child: Container(
                              height: 50,
                              width: 170,
                              child: Expanded(
                                child: ElevatedButton(
                                    onPressed: (){
                                      if(total <= 0)
                                      {
                                        final snackBar = SnackBar(
                                          content: const Text('A mesa não possui itens', style: TextStyle(color: Colors.white),),
                                          backgroundColor: _corLaranjaSF,
                                          duration: Duration(seconds: 2),
                                          action: SnackBarAction(
                                            label: 'Ok',
                                            textColor: _corMarromSF,
                                            onPressed: () {
                                              // Some code to undo the change.
                                            },
                                          ),
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                      }
                                      else{
                                        Navigator.of(context).pop();
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) => Visualizar(numMesa)
                                            )
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
                                      primary: _corMarromSF,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  child: Row(
                                    children: <Widget>[
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(4, 0, 8, 0),
                                        child: Icon(
                                          Icons.remove_red_eye_outlined,
                                          color: _corLaranjaSF,
                                          size: 30,
                                        ),
                                      ),
                                      Text("Visualizar Itens", style: TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.left)
                                    ],
                                  ),
                                ),
                              )
                            ),
                          ),
                          Padding(
                            padding:  EdgeInsets.all(4),
                            child: Container(
                              height: 50,
                              width: 170,
                              child: Expanded(
                                child: ElevatedButton(
                                    onPressed: (){
                                      if(total <= 0)
                                      {
                                        final snackBar = SnackBar(
                                          content: const Text('A mesa não possui itens', style: TextStyle(color: Colors.white),),
                                          backgroundColor: _corLaranjaSF,
                                          duration: Duration(seconds: 2),
                                          action: SnackBarAction(
                                            label: 'Ok',
                                            textColor: _corMarromSF,
                                            onPressed: () {
                                              // Some code to undo the change.
                                            },
                                          ),
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                      }
                                      else{
                                        Navigator.of(context).pop();
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) => Fechar(numMesa, total, _parametros.ip_impressora, _parametros.qtd_vias_imprimir, identificador)
                                            )
                                        )
                                        .then((value) => {
                                          this.setState(() {
                                            bool _visibility = false;
                                            _recupera_infos_mesas_existentes(_parametros.nome_garcom, _parametros.qtd_colunas);
                                            })
                                          });
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
                                      primary: _corMarromSF,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  child: Row(
                                    children: <Widget>[
                                      Padding(
                                          padding: EdgeInsets.fromLTRB(4, 0, 8, 0),
                                          child: Icon(
                                            Icons.monetization_on_outlined,
                                            color: _corLaranjaSF,
                                            size: 30,
                                          ),
                                      ),
                                      Text("Fechar Conta", style: TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.left)
                                    ],
                                  ),
                                ),
                              )
                            ),
                          ),
                          TextButton(onPressed: () {
                            Navigator.of(context).pop();
                          },
                              child: Text('Sair', style: TextStyle(color: _corMarromSF, fontSize: 16.0),))
                        ],
                      ),
                    ),
                  ),
                ),
                onWillPop: () async => true
            )
        ),
      ),
    );
  }

  mostrarDialogoParametros()
  {
    int _primeiro_acesso = 0; // 0 - NAO || 1 - SIM
    if(_parametros.qtd_mesas == 0)
      _primeiro_acesso = 1;
    _parametro_qtd_mesas_antigo = _parametros.qtd_mesas;
    _controllerNome.text = _parametros.nome_garcom.toString();
    _controllerQtdMesas.text = _parametros.qtd_mesas.toString();
    _controllerQtdColunas.text = _parametros.qtd_colunas.toString();
    _controllerQtdVias.text = _parametros.qtd_vias_imprimir.toString();
    _controllerIpImp.text = _parametros.ip_impressora.toString();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ScaffoldMessenger(
        child: Builder(
            builder: (context) => WillPopScope(
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  body: Dialog(
                    elevation: 6,
                    insetAnimationDuration: Duration(seconds: 1),
                    insetAnimationCurve: Curves.slowMiddle,
                    insetPadding: EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), //this right here
                    child: Container(
                      //height: 300.0,
                      //width: 300.0,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Padding(
                            padding:  EdgeInsets.all(8.0),
                            child: Text('Parâmetros', style: TextStyle(color: Color(0xff3d2314), fontSize: 28, fontWeight: FontWeight.w900),),
                          ),
                          Padding(
                            padding:  EdgeInsets.all(8.0),
                            child: TextField(
                              controller: _controllerNome,
                              keyboardType: TextInputType.name,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              maxLength: 25,
                              cursorColor: Color(0xff3d2314),
                              style: TextStyle(
                                  color: Color(0xffff6900),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700
                              ),
                              decoration: InputDecoration(
                                counterText: "",
                                contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                labelText: "Nome do Garçom",
                                labelStyle: TextStyle(color: Color(0xff3d2314)),
                                fillColor: Colors.white,
                                hoverColor: Color(0xff3d2314),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(width: 2, color: Color(0xff3d2314)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(width: 2, color: Color(0xff3d2314)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding:  EdgeInsets.all(8.0),
                            child: TextField(
                              controller: _controllerQtdMesas,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              maxLength: 2,
                              cursorColor: Color(0xff3d2314),
                              style: TextStyle(
                                  color: Color(0xffff6900),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700
                              ),
                              decoration: InputDecoration(
                                counterText: "",
                                contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                labelText: "Quantidade de Mesas",
                                labelStyle: TextStyle(color: Color(0xff3d2314)),
                                fillColor: Colors.white,
                                hoverColor: Color(0xff3d2314),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(width: 2, color: Color(0xff3d2314)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(width: 2, color: Color(0xff3d2314)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding:  EdgeInsets.all(8.0),
                            child: TextField(
                              controller: _controllerQtdColunas,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              maxLength: 2,
                              cursorColor: Color(0xff3d2314),
                              style: TextStyle(
                                  color: Color(0xffff6900),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700
                              ),
                              decoration: InputDecoration(
                                counterText: "",
                                contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                labelText: "Quantidade de Colunas",
                                labelStyle: TextStyle(color: Color(0xff3d2314)),
                                fillColor: Colors.white,
                                hoverColor: Color(0xff3d2314),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(width: 2, color: Color(0xff3d2314)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(width: 2, color: Color(0xff3d2314)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding:  EdgeInsets.all(8.0),
                            child: TextField(
                              controller: _controllerQtdVias,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              maxLength: 2,
                              cursorColor: Color(0xff3d2314),
                              style: TextStyle(
                                  color: Color(0xffff6900),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700
                              ),
                              decoration: InputDecoration(
                                counterText: "",
                                contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                labelText: "Quantidade de Vias Imprimir",
                                labelStyle: TextStyle(color: Color(0xff3d2314)),
                                fillColor: Colors.white,
                                hoverColor: Color(0xff3d2314),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(width: 2, color: Color(0xff3d2314)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(width: 2, color: Color(0xff3d2314)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding:  EdgeInsets.all(8.0),
                            child: TextField(
                              controller: _controllerIpImp,
                              keyboardType: TextInputType.number,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              maxLength: 15,
                              cursorColor: Color(0xff3d2314),
                              style: TextStyle(
                                color: Color(0xffff6900),
                                fontSize: 16,
                                fontWeight: FontWeight.w700
                              ),
                              decoration: InputDecoration(
                                counterText: "",
                                contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                labelText: "IP da Impressora",
                                labelStyle: TextStyle(color: Color(0xff3d2314)),
                                fillColor: Colors.white,
                                hoverColor: Color(0xff3d2314),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(width: 2, color: Color(0xff3d2314)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(width: 2, color: Color(0xff3d2314)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                              padding: EdgeInsets.all(8)),
                          TextButton(onPressed: () {
                            FocusScope.of(context).unfocus();
                            if(!_controllerNome.text.isEmpty && !_controllerQtdMesas.text.isEmpty && !_controllerQtdVias.text.isEmpty && int.parse(_controllerQtdMesas.text) > 0 && !_controllerQtdVias.text.isEmpty && int.parse(_controllerQtdMesas.text) > 0 && !_controllerQtdColunas.text.isEmpty && int.parse(_controllerQtdColunas.text) > 0 && !_controllerIpImp.text.isEmpty)
                            {
                              int _qtd_adicionar = 0;
                              int _qtd_remover = 0;
                              if(_parametro_qtd_mesas_antigo != int.parse(_controllerQtdMesas.text))
                              {
                                if(_parametro_qtd_mesas_antigo > int.parse(_controllerQtdMesas.text) && _listaMesas.length > 0) //remoção de mesas
                                    {//é necessário verificar se as últimas mesas da lista não estão em aberto, para somente depois disso remover
                                  _qtd_remover = _parametro_qtd_mesas_antigo - int.parse(_controllerQtdMesas.text);
                                  bool _pode_excluir = true;
                                  for(int i = _listaMesas.length; i >= int.parse(_controllerQtdMesas.text); i--)
                                  {
                                    if(_listaMesas[i-1].status == 1)//mesa aberta, não pode ser excluída
                                        {
                                      _pode_excluir = false;
                                      break;
                                    }

                                  }
                                  if(!_pode_excluir)
                                  {
                                    final snackBar = SnackBar(
                                      backgroundColor: Color(0xff3d2314),
                                      content: Text(
                                        'Não é possível excluir mesas que estão em aberto. Feche-as para executar este processo',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: Colors.white
                                        ),
                                      ),
                                      action: SnackBarAction(
                                        label: 'Ok',
                                        textColor: Colors.blueAccent,
                                        onPressed: () {
                                        },
                                      ),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                    return;
                                  }
                                }
                                if(_parametro_qtd_mesas_antigo < int.parse(_controllerQtdMesas.text) && _listaMesas.length > 0) //adição de mesas
                                    {//adicionar mais mesas
                                  _qtd_adicionar = int.parse(_controllerQtdMesas.text) - _parametro_qtd_mesas_antigo;
                                }
                              }

                              _parametros.nome_garcom = _controllerNome.text;
                              _parametros.qtd_mesas = int.parse(_controllerQtdMesas.text);
                              _parametros.qtd_colunas = int.parse(_controllerQtdColunas.text);
                              _parametros.qtd_vias_imprimir = int.parse(_controllerQtdVias.text);
                              _parametros.ip_impressora = _controllerIpImp.text;

                              if(_qtd_adicionar == 0 && _qtd_remover == 0)//sem alteração
                                _salvarParametros(_primeiro_acesso);
                              if(_qtd_adicionar != 0 && _qtd_remover == 0)//aumento de mesas
                                  {
                                _salvarParametros(_primeiro_acesso);
                                _alterarMesas(0, _qtd_adicionar);
                              }
                              if(_qtd_adicionar == 0 && _qtd_remover != 0)//redução de mesas
                                  {
                                _salvarParametros(_primeiro_acesso);
                                _alterarMesas(1, _qtd_remover);
                              }

                              Navigator.of(context).pop();
                            }
                            else
                            {
                              final snackBar = SnackBar(
                                backgroundColor: Color(0xff3d2314),
                                content: Text(
                                  'Existem campos não preenchidos ou preenchidos incorretamente. Verifique e tente novamente.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.white
                                  ),
                                ),
                                action: SnackBarAction(
                                  label: 'Ok',
                                  textColor: Colors.blueAccent,
                                  onPressed: () {
                                  },
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(snackBar);
                            }
                          },
                              child: Text('Salvar', style: TextStyle(color: _corLaranjaSF, fontSize: 18.0, fontWeight: FontWeight.w800),))
                        ],
                      ),
                    ),
                  ),
                ),
                onWillPop: () async => false
            )
        ),
      ),
    );
  }
  _recupera_infos_mesas_existentes(String _nome, int _qtd) async
  {
    _listaMesas.clear();
    final ref = FirebaseDatabase.instance.ref();
    final snapshot = await ref.child("mesas").get();
    if (snapshot.exists) {
      for(DataSnapshot ds in snapshot.children)
      {
        Mesa _itemLista = Mesa();
        final json = ds.value as Map<dynamic, dynamic>;
        _itemLista = Mesa.fromJson(json);
        _listaMesas.add(_itemLista);
      }
      _carregaDadosMesas(_nome, _qtd);
    }
  }
  _alterarMesas(int parametro, int qtd) async{//0 - adicionar | 1 - remover
    if(parametro == 0){//adicionar mesas
      int _ultima_mesa_registrada = _listaMesas.last.numero;
      for(int i = 1; i <= qtd; i++)
      {
        Mesa _mesa = Mesa();
        _mesa.numero = i + _ultima_mesa_registrada;
        _mesa.status = 0;
        _mesa.total = 0;
        final json = _mesa.toJson();
        final ref = FirebaseDatabase.instance.ref("mesas/" + _mesa.numero.toString());
        await ref.set(json);
      }
      _carregaDadosMesas(_parametros.nome_garcom, _parametros.qtd_colunas);
    }
    else{//remover mesas
      int novo_total = _listaMesas.length - qtd;
      for(int i = _listaMesas.length; i > novo_total; i--)
      {
        await FirebaseDatabase.instance.ref().child('mesas/').child(i.toString()).remove();
      }
    }
    _recupera_infos_mesas_existentes(_parametros.nome_garcom, _parametros.qtd_colunas);
  }
}


