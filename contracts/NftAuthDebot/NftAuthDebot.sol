pragma ton-solidity = 0.47.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "include.sol";

interface INftRoot{
    function resolveCodeHashIndex(
        address addrRoot,
        address addrOwner
    ) external view returns (uint256 codeHashIndex);
}

interface IData{
    function getOwner() external view returns(address addrOwner);
}

contract NftAuthDebot is Debot {

    string _lastStr = "Приятно было пообщаться, заглядывай еще! 😉";
    string _errorStr = "Forbitten! у вас нет нужной NFT";
    string _debotName = "Itgold nft authentication debot";
    address _supportAddr = address.makeAddrStd(0, 0x5fb73ece6726d59b877c8194933383978312507d06dda5bcf948be9d727ede4b);

    string[] _helloStrings;
    string[] _answerStrings;
    string[] _continueStrings;

    address[] _nftList;
    address _nftRoot = address(0);
    address _userAddr;

    AccData[] _indexes;

    bytes _icon;

    function start() public override {
        getAddress();
    }

    function getAddress() public {
        UserInfo.getAccount(tvm.functionId(setAddress));
    }

    function setAddress(address value) public {
        _userAddr = value;
        checkOwnershipUseRoot();
    }

    function checkOwnershipUseRoot() public {
        if (_nftRoot.value != 0) {
            getIndexCodeHash(tvm.functionId(onGetCodeHashSuccess), tvm.functionId(onGetCodeHashError));
        } else {
            checkOwnershipUseNfts();
        }
    }

    function getIndexCodeHash(uint32 answerId, uint32 errorId) public view {
        optional(uint256) none;
        INftRoot(_nftRoot).resolveCodeHashIndex{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: none,
            time: uint64(now),
            expire: 0,
            callbackId: answerId,
            onErrorId: errorId
        }(_nftRoot, _userAddr);
    }

    function onGetCodeHashError(uint32 sdkError, uint32 exitCode) public {
        _indexes[0] = _indexes[_indexes.length - 1];
        _indexes.pop();
        checkIndexes();
    }

    function onGetCodeHashSuccess(uint256 indexCodeHash) public {
        uint256 _codeHashIndex = indexCodeHash;
        buildIndexCodeData(_codeHashIndex);
    } 

    function buildIndexCodeData(uint256 indexCodeHash) public{
        Sdk.getAccountsDataByHash(
            tvm.functionId(setAccounts),
            indexCodeHash,
            address.makeAddrStd(0, 0)
        );
    }

    function setAccounts(AccData[] accounts) public {

        _indexes = accounts;
        checkIndexes();
    }

    function checkIndexes() public {
        if(_indexes.length != 0){
            Sdk.getAccountType(tvm.functionId(checkIndexAddressStatus), _indexes[0].id);
        } else {
            checkOwnershipUseNfts();
        }
    }

    function checkIndexAddressStatus(int8 acc_type) public {
        if (checkIndexStatus(acc_type)) {
            _start();
        } else {
            _indexes[0] = _indexes[_indexes.length - 1];
            _indexes.pop();
            checkIndexes();
        }
    }

    function checkIndexStatus(int8 acc_type) public returns (bool) {
        if (acc_type == -1)  {
            Terminal.print(0, "Address is inactive");
            return false;
        }
        if (acc_type == 0) {
            Terminal.print(0, "Address is unitialized");
            return false;
        }
        if (acc_type == 2) {
            Terminal.print(0, "Address is frozen");
            return false;
        }
        return true;
    }

    function checkOwnershipUseNfts() public {
        if (_nftList.length != 0) {
            getOwner(tvm.functionId(onGetOwnerSuccess), tvm.functionId(onGetOwnerError));
        } else {
            dontHaveNft();
        }
    }

    function getOwner(uint32 answerId, uint32 errorId) public view {
        optional(uint256) none;
        IData(_nftList[0]).getOwner{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: none,
            time: uint64(now),
            expire: 0,
            callbackId: answerId,
            onErrorId: errorId
        }();
    }

    function onGetOwnerSuccess(address addrOwner) public {
        if (addrOwner == _userAddr) {
            _start();
        } else {
            _nftList[0] = _nftList[_nftList.length - 1];
            _nftList.pop();
            checkOwnershipUseNfts();
        }
    }

    function onGetOwnerError(uint32 sdkError, uint32 exitCode) public {
        _nftList[0] = _nftList[_nftList.length - 1];
        _nftList.pop();
        checkOwnershipUseNfts();
    }

    function _start() public {
        genRandom(tvm.functionId(genHelloStr));
    }

    function genRandom(uint32 answerId) public {
        Sdk.genRandom(answerId, 8); /// bytes buffer
    }

    function genHelloStr(bytes buffer) public {
        if (_helloStrings.length == 0) { return; }
        uint256 hash = sha256(format("{}", buffer));
        uint256 randomNumber = hash % _helloStrings.length;
        inputQuestion(_helloStrings[randomNumber]);
    }

    function inputQuestion(string helloStr) public {
        Terminal.input(tvm.functionId(genAnswer), helloStr, true);
    }

    function genAnswer(string value) public {
        genRandom(tvm.functionId(calcAnswer));
    }

    function calcAnswer(bytes buffer) public {
        if (_answerStrings.length == 0) { return; }
        uint256 hash = sha256(format("{}", buffer));
        uint randomNumber = hash % _answerStrings.length;
        Terminal.print(tvm.functionId(genContinuePhrase), _answerStrings[randomNumber]);
    }

    function genContinuePhrase() public {
        genRandom(tvm.functionId(calcContinuePhrase));
    }

    function calcContinuePhrase(bytes buffer) public {
        if (_continueStrings.length == 0) { return; }
        uint256 hash = sha256(format("{}", buffer));
        uint randomNumber = hash % _continueStrings.length;
        menu(_continueStrings[randomNumber]);
    }

    function menu(string continueStr) public {
        MenuItem[] _items;

        _items.push( MenuItem("Да", "", tvm.functionId(_start)));
        _items.push( MenuItem("Нет", "", tvm.functionId(finish)));
        
        Menu.select(continueStr, "", _items);
    }

    function finish() public {
        Terminal.print(0, _lastStr);
    }

    function dontHaveNft() public {
        Terminal.print(0, _errorStr);
    }

    /// @notice Returns Metadata about DeBot.
    function getDebotInfo() public functionID(0xDEB) override view returns(
        string name, string version, string publisher, string key, string author,
        address support, string hello, string language, string dabi, bytes icon
    ) {
        name = _debotName;
        version = "1.0";
        publisher = "https://itgold.io/";
        key = "User authentication use nft";
        author = "https://itgold.io/";
        support = _supportAddr;
        hello = "Hello, i'm itgold nft authentication debot";
        language = "ru";
        dabi = m_debotAbi.get();
        icon = _icon;
    }

    function getRequiredInterfaces() public view override returns (uint256[] interfaces) {
        return [ Terminal.ID, UserInfo.ID, Menu.ID, Sdk.ID ];
    }

    function addHelloString(string helloString) public checkPubkey {
        tvm.accept();

        _helloStrings.push(helloString);
    }

    function addAnswerString(string answerString) public checkPubkey {
        tvm.accept();

        _answerStrings.push(answerString);
    } 

    function addContinueString(string continueString) public checkPubkey {
        tvm.accept();

        _continueStrings.push(continueString);
    }

    function deleteHelloString(uint64 id) public checkPubkey {
        require(id < _helloStrings.length);
        tvm.accept();

        delete _helloStrings[id];
        _helloStrings[id] = _helloStrings[_helloStrings.length - 1];
        _helloStrings.pop();
    }

    function deleteAnswerString(uint64 id) public checkPubkey {
        require(id < _answerStrings.length);
        tvm.accept();

        delete _answerStrings[id];
        _answerStrings[id] = _answerStrings[_answerStrings.length - 1];
        _answerStrings.pop();
    }

    function deleteContinueString(uint64 id) public checkPubkey {
        require(id < _continueStrings.length);
        tvm.accept();

        delete _continueStrings[id];
        _continueStrings[id] = _continueStrings[_continueStrings.length - 1];
        _continueStrings.pop();
    }

    function getHelloStrings() public view returns(string[] helloStrings) {
        return _helloStrings;
    }

    function getAnswerStrings() public view returns(string[] answerStrings) {
        return _answerStrings;
    }

    function getContinueString() public view returns(string[] continueStrings) {
        return _continueStrings;
    }

    function setNftRootAddr(address nftRoot) public checkPubkey {
        tvm.accept();
        _nftRoot = nftRoot;
    }

    function setNftList(address[] nftList) public checkPubkey {
        tvm.accept();
        _nftList = nftList;
    }

    function setLastStr(string lastStr) public checkPubkey {
        tvm.accept();
        _lastStr = lastStr;
    }

    function setErrorStr(string errorStr) public checkPubkey {
        tvm.accept();
        _errorStr = errorStr;
    }

    function burn(address dest) public checkPubkey {
        tvm.accept();
        selfdestruct(dest);
    }

    modifier checkPubkey() {
        require(msg.pubkey() == tvm.pubkey(), 100);
        _;
    }

}