import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:walletconnect_dart/walletconnect_dart.dart';
import 'package:web3dart/web3dart.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var _uri, account;
  SessionStatus? _session;
  var myData = BigInt.zero;
  late Client client;
  late Web3Client web3client;
  late DeployedContract contract;
  String? name;
  String? symbol;
  String contractAddress = "0xB4F284Df7D40f40327db4A27C855BB1f909891c2";
  final rpc_url =
      "https://goerli.infura.io/v3/4009a1b4ddf34fc6ad587c4b10dabe52";

  var connector = WalletConnect(
      bridge: 'https://bridge.walletconnect.org',
      clientMeta: const PeerMeta(
          name: 'My App',
          description: 'An app for Connect with MetaMask and Send Transaction',
          url: 'https://walletconnect.org',
          icons: [
            'https://files.gitbook.com/v0/b/gitbook-legacy-files/o/spaces%2F-LJJeCjcLrr53DcT1Ml7%2Favatar.png?alt=media'
          ]));

  loginUsingMetamask(BuildContext context) async {
    if (!connector.connected) {
      try {
        var session = await connector.createSession(onDisplayUri: (uri) async {
          _uri = uri;
          await launchUrlString(uri, mode: LaunchMode.externalApplication);
          contract = await loadContract();
        });
        setState(() {
          _session = session;
          account = _session!.accounts[0];
        });
      } catch (exp) {
        print(exp);
      }
    }
  }

  Future<DeployedContract> loadContract() async {
    String abi = await rootBundle.loadString("assets/abi.json");
    final contract = DeployedContract(ContractAbi.fromJson(abi, "AsadToken"),
        EthereumAddress.fromHex(contractAddress));
    return contract;
  }

  Future<List<dynamic>> query(String name, List<dynamic> args) async {
    final contract = await loadContract();
    final ethFunction = contract.function(name);
    final result = await web3client.call(
        contract: contract, function: ethFunction, params: args);
    return result;
  }

  Future getTokenName() async {
    var response = await query("name", []);
    name = response[0];
    setState(() {});
  }

  Future getTokenSymbol() async {
    var response = await query("symbol", []);
    symbol = response[0];
    setState(() {});
  }

  Future getBalanceToken(String targetAddress) async {
    EthereumAddress toAddress = EthereumAddress.fromHex(targetAddress);
    var response = await query("balanceOf", [toAddress]);
    myData = response[0];
    setState(() {});
  }

  Future mintToken(BuildContext context) async {
    BigInt bigAmount = BigInt.from(100e18);
    EthereumAddress toAddress = EthereumAddress.fromHex(_session!.accounts[0]);
    var response = await submit("mint", [toAddress, bigAmount], context);
    return response;
  }

  Future transferToken(BuildContext context) async {
    BigInt bigAmount = BigInt.from(10e18);
    EthereumAddress toAddress =
        EthereumAddress.fromHex("0x95d214e60C1881FAcfca90D8909F0DdEE63F004f");
    var response = await submit("transfer", [toAddress, bigAmount], context);
    return response;
  }

  submit(String name, List<dynamic> args, BuildContext context) async {
    if (connector.connected) {
      try {
        EthereumWalletConnectProvider provider =
            EthereumWalletConnectProvider(connector);
        await launchUrlString(_uri, mode: LaunchMode.externalApplication);
        var data = contract.function(name).encodeCall(args);

        var p = await web3client.estimateGas(
          to: EthereumAddress.fromHex(contractAddress),
          sender: EthereumAddress.fromHex(_session!.accounts[0]),
          data: data,
        );
        var tx = await provider.sendTransaction(
          from: _session!.accounts[0],
          to: contractAddress,
          gas: p.toInt(),
          data: data,
        );
        TransactionReceipt? val = await web3client.getTransactionReceipt(tx);
        if (val?.status == null) {
          AlertDialog alert = AlertDialog(
            content: Row(children: [
              const CircularProgressIndicator(
                backgroundColor: Colors.red,
              ),
              Container(
                  margin: const EdgeInsets.only(left: 7),
                  child: const Text("Please Wait")),
            ]),
          );
          showDialog(
            barrierDismissible: false,
            context: context,
            builder: (BuildContext context) {
              return alert;
            },
          );
          Future.delayed(const Duration(seconds: 15), () async {
            TransactionReceipt? value =
                await web3client.getTransactionReceipt(tx);
            if (value?.status != null) {
              Navigator.pop(context);
              loadDialog(context, value!, tx);
            } else {
              Future.delayed(const Duration(seconds: 10), () async {
                TransactionReceipt? value =
                    await web3client.getTransactionReceipt(tx);
                if (value?.status != null) {
                  Navigator.pop(context);
                  loadDialog(context, value!, tx);
                }
              });
            }
          });
        }
      } catch (exp) {
        print(exp);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Please Connect with Metamask"),
      ));
    }
  }

  void loadDialog(BuildContext context, TransactionReceipt value, var hash) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Receipt"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [const Text("Status"), Text("${value.status}")],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Comluative Gas Price"),
                  Text("${value.cumulativeGasUsed}")
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("BlockNumber"),
                  Text("${value.blockNumber}")
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [const Text("Gas Used"), Text("${value.gasUsed}")],
              ),
              Divider(),
              const Text("Hash"),
              Divider(),
              Flexible(
                  child: Text(
                "$hash",
                style: TextStyle(fontSize: 10),
              ))
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Ok"),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    client = Client();
    web3client = Web3Client(rpc_url, client);
    // contract = await loadContract();
    // getBalanceToken(_session?.accounts[0] ?? "");
  }

  @override
  Widget build(BuildContext context) {
    if (_session != null) {
      getBalanceToken(_session?.accounts[0] ?? "");
      getTokenName();
      getTokenSymbol();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("ERC20 Integration"),
        centerTitle: true,
      ),
      drawer: Drawer(
          child: ListView(
        children: [
          (_session != null)
              ? UserAccountsDrawerHeader(
                  accountName: const Text("Asad"),
                  accountEmail: Text(account),
                  currentAccountPicture: const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text("A"),
                  ),
                )
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent),
                  onPressed: () => loginUsingMetamask(context),
                  child: const Text("Connect with Metamask")),
        ],
      )),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.only(top: 50),
            margin: const EdgeInsets.all(10),
            child: Text(
              name ?? "",
              style: const TextStyle(fontSize: 40),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 50),
            margin: const EdgeInsets.all(10),
            child: Text(
              "${EtherAmount.inWei(myData).getInEther} ${symbol ?? "Coin"}",
              style: const TextStyle(fontSize: 40),
            ),
          ),
          Center(
            child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent),
                onPressed: () => mintToken(context),
                child: const Text("Mint Token")),
          ),
          Center(
            child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => transferToken(context),
                child: const Text("Transfer Token")),
          ),
        ],
      ),
    );
  }
}
