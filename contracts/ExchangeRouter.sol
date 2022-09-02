pragma solidity ^0.5.12;
pragma experimental ABIEncoderV2;

import "./TransferHelper.sol";
import "./ReentrancyGuard.sol";
import "./SafeMath.sol";


interface poolStable {
    function exchange(uint128 i, uint128 j, uint256 dx, uint256 min_dy) external;
    function coins(uint256) external view returns (address);
}

interface v2{
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);
}



interface usdcPoolF{
    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
}

interface erc20 {
    function approve(address name,uint256 amount) external;
    function balanceOf(address name)  external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
}


interface v1{
    function getExchange(address token) external view returns (address payable);
}



contract ExchangeRouter is ReentrancyGuard {
    using SafeMath for uint256;

    address public old3pool;
    address public usdcPool;
    address public v2Router;
    address public v1Foctroy;
    address public usdt;
    address public usdj;
    address public tusd;
    address public usdc;
    uint256 public maxNum=1606938044258990275541962092341162602522202993782792835301375;      //ffffffffffffffffffffffffffffffffffffffffffffffffff
    mapping(address=>mapping(address=>bool)) public approveToken;
    mapping(address=>mapping(uint=>address)) public poolToken;
    mapping(address=>bool) existPool;
    address public owner;
    address public admin;


    constructor(
        address _old3pool,
        address _usdcPool,
        address _v2Router,
        address _v1Foctroy,
        address _usdt,
        address _usdj,
        address _tusd,
        address _usdc
    ) public{
        old3pool=_old3pool;
        usdcPool=_usdcPool;
        v2Router=_v2Router;
        v1Foctroy=_v1Foctroy;
        usdt=_usdt;
        usdj=_usdj;
        tusd=_tusd;
        usdc=_usdc;
        owner=msg.sender;
        admin=msg.sender;

        require(TransferHelper.safeApprove(_usdt,_old3pool,maxNum),"wrong approve");
        require(TransferHelper.safeApprove(_usdt,_usdcPool,maxNum),"wrong approve");

        require(TransferHelper.safeApprove(_usdj,_old3pool,maxNum),"wrong approve");
        require(TransferHelper.safeApprove(_usdj,_usdcPool,maxNum),"wrong approve");

        require(TransferHelper.safeApprove(_tusd,_old3pool,maxNum),"wrong approve");
        require(TransferHelper.safeApprove(_tusd,_usdcPool,maxNum),"wrong approve");

        require(TransferHelper.safeApprove(_usdc,_usdcPool,maxNum),"wrong approve");
    }


    /************************************************************************************************
    ****************************************poolStable*******************************************************
    *************************************************************************************************/


    /****************************************ForNewPool****************************************************/

    modifier onlyOwner{
        require(msg.sender==owner,"Only owner can do that!");
        _;
    }


    modifier onlyAdmin{
        require(msg.sender==admin,"Only admin can do that!");
        _;
    }


    function transferOwnership(address newOwner) public onlyOwner{
        owner=newOwner;
    }

    function transferAdminship(address newAdmin) public onlyAdmin{
        admin=newAdmin;
    }


    function stablePoolExchange(address pool,uint128 i, uint128 j, uint256 dx, uint256 min_dy)external nonReentrant {
        address token=poolStable(pool).coins(i);
        address tokenOut=poolStable(pool).coins(j);

        uint256[2] memory d;
        d[0]=erc20(token).balanceOf(address(this));
        require(TransferHelper.safeTransferFrom(token,msg.sender,address(this),dx),"wrong transfer");
        d[1]=(erc20(token).balanceOf(address(this))).sub(d[0]);
        uint256 dy=erc20(tokenOut).balanceOf(address(this));
        poolStable(pool).exchange(i, j, d[1], min_dy);
        dy=(erc20(tokenOut).balanceOf(address(this))).sub(dy);
        if(dy>0){
            require(TransferHelper.safeTransfer(tokenOut,msg.sender,dy),"wrong transfer");
        }
    }



    function addPool(address pool,address[] memory token) public onlyOwner {
        require(existPool[pool]==false,"pool exist");
        for (uint i=0;i<token.length;i++){
            poolToken[pool][i]=token[i];
            require(TransferHelper.safeApprove(token[i],pool,maxNum),"wrong approve");
        }
        existPool[pool]=true;
    }

    function changePool(address pool,address[] memory token) public onlyAdmin {
        require(existPool[pool]==true,"pool not exist");
        for (uint i=0;i<token.length;i++){
            poolToken[pool][i]=token[i];
            require(TransferHelper.safeApprove(token[i],pool,maxNum),"wrong approve");
        }

    }




    /****************************************ForAlreadyPool****************************************************/

    function old3poolExchange(uint128 i, uint128 j, uint256 dx, uint256 min_dy) external nonReentrant {
        address token=poolStable(old3pool).coins(i);
        address tokenOut=poolStable(old3pool).coins(j);

        uint256[2] memory d;
        d[0]=erc20(token).balanceOf(address(this));
        require(TransferHelper.safeTransferFrom(token,msg.sender,address(this),dx),"wrong transfer");
        d[1]=(erc20(token).balanceOf(address(this))).sub(d[0]);
        uint256 dy=erc20(tokenOut).balanceOf(address(this));
        poolStable(old3pool).exchange(i, j, d[1], min_dy);
        dy=(erc20(tokenOut).balanceOf(address(this))).sub(dy);
        if(dy>0){
            require(TransferHelper.safeTransfer(tokenOut,msg.sender,dy),"wrong transfer");
        }
    }


    function usdcExchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external nonReentrant {
        address token;
        address tokenOut;

        uint256 inNu=uint256(i);
        uint256 outNu=uint256(j);
        require(i>=0,"wrong i");
        require(j>=0,"wrong j");

        if(i<1){
            token=poolStable(usdcPool).coins(inNu);
        }else{
            token=poolStable(old3pool).coins(inNu.sub(1));
        }

        if(j<1){
            tokenOut=poolStable(usdcPool).coins(outNu);
        }else{
            tokenOut=poolStable(old3pool).coins(outNu.sub(1));
        }

        uint256[2] memory d;
        d[0]=erc20(token).balanceOf(address(this));
        require(TransferHelper.safeTransferFrom(token,msg.sender,address(this),dx),"wrong transfer");
        d[1]=(erc20(token).balanceOf(address(this))).sub(d[0]);
        uint256 dy=erc20(tokenOut).balanceOf(address(this));
        usdcPoolF(usdcPool).exchange_underlying(i, j, d[1], min_dy);
        dy=(erc20(tokenOut).balanceOf(address(this))).sub(dy);
        if(dy>0){
            require(TransferHelper.safeTransfer(tokenOut,msg.sender,dy),"wrong transfer");
        }
    }




    /************************************************************************************************
    ****************************************v2*******************************************************
    *************************************************************************************************/



    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external nonReentrant returns (uint[] memory amounts){
        address token=path[0];
        if(approveToken[token][v2Router]==false){
            TransferHelper.safeApprove(token,v2Router,maxNum);
            approveToken[token][v2Router]=true;
        }
        uint256 dx=erc20(token).balanceOf(address(this));
        require(TransferHelper.safeTransferFrom(path[0],msg.sender,address(this),amountIn),"wrong transfer");
        dx=(erc20(token).balanceOf(address(this))).sub(dx);
        uint[] memory returnA = v2(v2Router).swapExactTokensForTokens(dx,amountOutMin,path,to,deadline);
        return returnA;
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external nonReentrant returns (uint[] memory amounts){
        address token=path[0];
        if(approveToken[token][v2Router]==false){
            TransferHelper.safeApprove(token,v2Router,maxNum);
            approveToken[token][v2Router]=true;
        }
        uint256[3] memory dx;
        dx[0]=erc20(token).balanceOf(address(this));
        require(TransferHelper.safeTransferFrom(path[0],msg.sender,address(this),amountInMax),"wrong transfer");
        dx[1]=(erc20(token).balanceOf(address(this))).sub(dx[0]);
        uint[] memory returnA = v2(v2Router).swapTokensForExactTokens(amountOut,dx[1],path,to,deadline);
        dx[2]=(erc20(token).balanceOf(address(this))).sub(dx[0]);
        if(dx[2]>0){
            require(TransferHelper.safeTransfer(token,msg.sender,dx[2]),"wrong transfer");
        }
        return returnA;
    }

    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
    external
    nonReentrant
    returns (uint[] memory amounts){
        address token=path[0];
        if(approveToken[token][v2Router]==false){
            TransferHelper.safeApprove(token,v2Router,maxNum);
            approveToken[token][v2Router]=true;
        }
        uint256[3] memory dx;
        dx[0]=erc20(token).balanceOf(address(this));
        require(TransferHelper.safeTransferFrom(path[0],msg.sender,address(this),amountInMax),"wrong transfer");
        dx[1]=(erc20(token).balanceOf(address(this))).sub(dx[0]);
        uint[] memory returnA = v2(v2Router).swapTokensForExactETH(amountOut, dx[1], path, to, deadline);
        dx[2]=(erc20(token).balanceOf(address(this))).sub(dx[0]);
        if(dx[2]>0){
            require(TransferHelper.safeTransfer(token,msg.sender,dx[2]),"wrong transfer");
        }
        return returnA;
    }


    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    nonReentrant
    returns (uint[] memory amounts){
        address token=path[0];
        if(approveToken[token][v2Router]==false){
            TransferHelper.safeApprove(token,v2Router,maxNum);
            approveToken[token][v2Router]=true;
        }
        uint256 dx=erc20(token).balanceOf(address(this));
        require(TransferHelper.safeTransferFrom(path[0],msg.sender,address(this),amountIn),"wrong transfer");
        dx=(erc20(token).balanceOf(address(this))).sub(dx);
        uint[] memory returnA = v2(v2Router).swapExactTokensForETH(dx, amountOutMin, path, to, deadline);
        return returnA;

    }

    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    nonReentrant
    payable
    returns (uint[] memory amounts){
        uint[] memory returnA = v2(v2Router).swapExactETHForTokens.value(msg.value)(amountOutMin, path, to, deadline);
        return returnA;
    }


    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
    external
    nonReentrant
    payable
    returns (uint[] memory amounts){
        uint256 dy=(address(this).balance).sub(msg.value);
        uint[] memory returnA = v2(v2Router).swapETHForExactTokens.value(msg.value)(amountOut, path, to, deadline);
        dy=(address(this).balance).sub(dy);
        if(dy>0){
            TransferHelper.safeTransferETH(msg.sender, dy);
        }
        return returnA;
    }


    /************************************************************************************************
    ****************************************v1*******************************************************
    *************************************************************************************************/


    /*********************************************tool****************************************************/

    function executeTransaction(address target, uint value, string memory signature, bytes memory data) internal returns (bool success, bytes memory returnData) {
        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }
        (success, returnData) = target.call.value(value)(callData);
    }

    function () external payable {}

    /*********************************************Input****************************************************/

    function tokenToTrxTransferInput(address token,uint256 tokens_sold, uint256 min_trx, uint256 deadline, address payable recipient) external nonReentrant returns (uint256){
        address payable poolAddr=v1(v1Foctroy).getExchange(token);
        if(approveToken[token][poolAddr]==false){
            TransferHelper.safeApprove(token,poolAddr,maxNum);
            approveToken[token][poolAddr]=true;
        }

        uint256 dx=erc20(token).balanceOf(address(this));
        require(TransferHelper.safeTransferFrom(token,msg.sender,address(this),tokens_sold),"wrong transfer");
        dx=(erc20(token).balanceOf(address(this))).sub(dx);


        uint256 addedSun;
        (bool isSuccess,bytes memory data) = executeTransaction(poolAddr, 0, "tokenToTrxTransferInput(uint256,uint256,uint256,address)", abi.encode(dx,min_trx,deadline,recipient));
        require(isSuccess,"wrong traction");
        if (isSuccess) {
            addedSun = abi.decode(data, (uint256));
        }
        return addedSun;



        //bytes4 methodHash = bytes4(keccak256(bytes('tokenToTrxTransferInput(uint256, uint256, uint256, address)')));
        //(bool success, bytes memory data) = pool.delegatecall(abi.encodeWithSelector(methodHash,0,1,100000,0));
        //bytes memory b3 = concat(methodHash,i,j,dx,min_dy);

        //pool.call(bytes4(keccak256("exchange_underlying(uint128, uint128, uint256, uint256)")), i, j,dx,min_dy);
        //(bool success, bytes memory data) = poolAddr.call(abi.encodeWithSelector(methodHash, dx, min_trx, deadline, recipient));

    }

    function tokenToTrxSwapInput(address token,uint256 tokens_sold, uint256 min_trx, uint256 deadline) external nonReentrant returns (uint256){

        address payable poolAddr=v1(v1Foctroy).getExchange(token);
        if(approveToken[token][poolAddr]==false){
            TransferHelper.safeApprove(token,poolAddr,maxNum);
            approveToken[token][poolAddr]=true;
        }

        uint256 dx=erc20(token).balanceOf(address(this));
        require(TransferHelper.safeTransferFrom(token,msg.sender,address(this),tokens_sold),"wrong transfer");
        dx=(erc20(token).balanceOf(address(this))).sub(dx);

        //uint256 returnA = v1Swap(token).tokenToTrxTransferInput(1000000000000000000, 1, block.timestamp + 10,msg.sender);

        uint256 addedSun;
        (bool isSuccess,bytes memory data) = executeTransaction(poolAddr, 0, "tokenToTrxTransferInput(uint256,uint256,uint256,address)", abi.encode(dx,min_trx,deadline,msg.sender));
        require(isSuccess,"wrong traction");
        if (isSuccess) {
            addedSun = abi.decode(data, (uint256));
        }
        return addedSun;
    }


    function tokenToTokenTransferInput(address token,uint256 tokens_sold,uint256 min_tokens_bought,uint256 min_trx_bought,uint256 deadline,address recipient,address tokenOut)external nonReentrant returns (uint256){
        address payable poolAddr=v1(v1Foctroy).getExchange(token);
        if(approveToken[token][poolAddr]==false){
            TransferHelper.safeApprove(token,poolAddr,maxNum);
            approveToken[token][poolAddr]=true;
        }

        uint256 dx=erc20(token).balanceOf(address(this));
        require(TransferHelper.safeTransferFrom(token,msg.sender,address(this),tokens_sold),"wrong transfer");
        dx=(erc20(token).balanceOf(address(this))).sub(dx);

        //uint256 returnA = v1Swap(token).tokenToTrxTransferInput(1000000000000000000, 1, block.timestamp + 10,msg.sender);

        uint256 addedSun;
        (bool isSuccess,bytes memory data) = executeTransaction(poolAddr, 0, "tokenToTokenTransferInput(uint256,uint256,uint256,uint256,address,address)", abi.encode(dx,min_tokens_bought,min_trx_bought,deadline,recipient,tokenOut));
        require(isSuccess,"wrong traction");
        if (isSuccess) {
            addedSun = abi.decode(data, (uint256));
        }
        return addedSun;

    }


    function tokenToTokenSwapInput(address token,uint256 tokens_sold,uint256 min_tokens_bought,uint256 min_trx_bought,uint256 deadline,address tokenOut)external nonReentrant returns (uint256){
        address payable poolAddr=v1(v1Foctroy).getExchange(token);
        if(approveToken[token][poolAddr]==false){
            TransferHelper.safeApprove(token,poolAddr,maxNum);
            approveToken[token][poolAddr]=true;
        }

        uint256 dx=erc20(token).balanceOf(address(this));
        require(TransferHelper.safeTransferFrom(token,msg.sender,address(this),tokens_sold),"wrong transfer");
        dx=(erc20(token).balanceOf(address(this))).sub(dx);

        //uint256 returnA = v1Swap(token).tokenToTrxTransferInput(1000000000000000000, 1, block.timestamp + 10,msg.sender);

        uint256 addedSun;
        (bool isSuccess,bytes memory data) = executeTransaction(poolAddr, 0, "tokenToTokenTransferInput(uint256,uint256,uint256,uint256,address,address)", abi.encode(dx,min_tokens_bought,min_trx_bought,deadline,msg.sender,tokenOut));
        require(isSuccess,"wrong traction");
        if (isSuccess) {
            addedSun = abi.decode(data, (uint256));
        }
        return addedSun;


    }


    function trxToTokenTransferInput(address token,uint256 min_tokens, uint256 deadline, address recipient) external nonReentrant payable returns(uint256){
        address payable poolAddr=v1(v1Foctroy).getExchange(token);

        uint256 addedSun;
        (bool isSuccess,bytes memory data) = executeTransaction(poolAddr, msg.value, "trxToTokenTransferInput(uint256,uint256,address)", abi.encode(min_tokens,deadline,recipient));
        require(isSuccess,"wrong traction");
        if (isSuccess) {
            addedSun = abi.decode(data, (uint256));
        }
        return addedSun;


    }


    function trxToTokenSwapInput(address token,uint256 min_tokens, uint256 deadline) external nonReentrant payable returns(uint256){
        address payable poolAddr=v1(v1Foctroy).getExchange(token);

        uint256 addedSun;
        (bool isSuccess,bytes memory data) = executeTransaction(poolAddr, msg.value, "trxToTokenTransferInput(uint256,uint256,address)", abi.encode(min_tokens,deadline,msg.sender));
        require(isSuccess,"wrong traction");
        if (isSuccess) {
            addedSun = abi.decode(data, (uint256));
        }
        return addedSun;

    }


    /*********************************************outPut****************************************************/

    function tokenToTokenTransferOutput(address token,uint256 tokens_bought,uint256 max_tokens_sold,uint256 max_trx_sold,uint256 deadline,address recipient,address tokenOut) public nonReentrant returns (uint256){
        address payable poolAddr=v1(v1Foctroy).getExchange(token);
        if(approveToken[token][poolAddr]==false){
            TransferHelper.safeApprove(token,poolAddr,maxNum);
            approveToken[token][poolAddr]=true;
        }

        uint256[3] memory dx;
        dx[0]=erc20(token).balanceOf(address(this));
        require(TransferHelper.safeTransferFrom(token,msg.sender,address(this),max_tokens_sold),"wrong transfer");
        dx[1]=(erc20(token).balanceOf(address(this))).sub(dx[0]);

        //uint256 dy=erc20(token).balanceOf(address(this));
        uint256 addedSun;
        (bool isSuccess,bytes memory data) = executeTransaction(poolAddr, 0, "tokenToTokenTransferOutput(uint256,uint256,uint256,uint256,address,address)", abi.encode(tokens_bought,dx[1],max_trx_sold,deadline,recipient,tokenOut));
        require(isSuccess,"wrong traction");
        dx[2]=(erc20(token).balanceOf(address(this))).sub(dx[0]);
        if(dx[2]>0){
            require(TransferHelper.safeTransfer(token,msg.sender,dx[2]),"wrong transfer");
        }
        if (isSuccess) {
            addedSun = abi.decode(data, (uint256));
        }

        return addedSun;

    }

    function tokenToTokenSwapOutput(address token,uint256 tokens_bought,uint256 max_tokens_sold,uint256 max_trx_sold,uint256 deadline,address tokenOut) public nonReentrant returns (uint256){
        address payable poolAddr=v1(v1Foctroy).getExchange(token);
        if(approveToken[token][poolAddr]==false){
            TransferHelper.safeApprove(token,poolAddr,maxNum);
            approveToken[token][poolAddr]=true;
        }

        uint256[3] memory dx;
        dx[0]=erc20(token).balanceOf(address(this));
        require(TransferHelper.safeTransferFrom(token,msg.sender,address(this),max_tokens_sold),"wrong transfer");
        dx[1]=(erc20(token).balanceOf(address(this))).sub(dx[0]);

        //uint256 returnA = v1Swap(token).tokenToTrxTransferInput(1000000000000000000, 1, block.timestamp + 10,msg.sender);
        uint256 addedSun;
        (bool isSuccess,bytes memory data) = executeTransaction(poolAddr, 0, "tokenToTokenTransferOutput(uint256,uint256,uint256,uint256,address,address)", abi.encode(tokens_bought,dx[1],max_trx_sold,deadline,msg.sender,tokenOut));
        require(isSuccess,"wrong traction");
        dx[2]=(erc20(token).balanceOf(address(this))).sub(dx[0]);
        if(dx[2]>0){
            require(TransferHelper.safeTransfer(token,msg.sender,dx[2]),"wrong transfer");
        }
        if (isSuccess) {
            addedSun = abi.decode(data, (uint256));
        }
        return addedSun;

    }

    function trxToTokenTransferOutput(address token,uint256 tokens_bought, uint256 deadline, address recipient) public payable nonReentrant returns (uint256) {
        address payable poolAddr=v1(v1Foctroy).getExchange(token);

        uint256 dx=(address(this).balance).sub(msg.value);
        uint256 addedSun;
        (bool isSuccess,bytes memory data) = executeTransaction(poolAddr, msg.value, "trxToTokenTransferOutput(uint256,uint256,address)", abi.encode(tokens_bought,deadline,recipient));
        require(isSuccess,"wrong traction");
        dx=(address(this).balance).sub(dx);
        if(dx>0){
            TransferHelper.safeTransferETH(msg.sender, dx);
        }
        if (isSuccess) {
            addedSun = abi.decode(data, (uint256));
        }
        return addedSun;

    }

    function trxToTokenSwapOutput(address token,uint256 tokens_bought, uint256 deadline) public payable nonReentrant returns(uint256){
        address payable poolAddr=v1(v1Foctroy).getExchange(token);

        uint256 dx=(address(this).balance).sub(msg.value);
        uint256 addedSun;
        (bool isSuccess,bytes memory data) = executeTransaction(poolAddr, msg.value, "trxToTokenTransferOutput(uint256,uint256,address)", abi.encode(tokens_bought,deadline,msg.sender));
        require(isSuccess,"wrong traction");
        dx=(address(this).balance).sub(dx);
        if(dx>0){
            TransferHelper.safeTransferETH(msg.sender, dx);
        }
        if (isSuccess) {
            addedSun = abi.decode(data, (uint256));
        }
        return addedSun;

    }

    function tokenToTrxSwapOutput(address token,uint256 trx_bought, uint256 max_tokens, uint256 deadline) public nonReentrant returns (uint256){
        address payable poolAddr=v1(v1Foctroy).getExchange(token);
        if(approveToken[token][poolAddr]==false){
            TransferHelper.safeApprove(token,poolAddr,maxNum);
            approveToken[token][poolAddr]=true;
        }

        uint256[3] memory dx;
        dx[0]=erc20(token).balanceOf(address(this));
        require(TransferHelper.safeTransferFrom(token,msg.sender,address(this),max_tokens),"wrong transfer");
        dx[1]=(erc20(token).balanceOf(address(this))).sub(dx[0]);

        //uint256 returnA = v1Swap(token).tokenToTrxTransferInput(1000000000000000000, 1, block.timestamp + 10,msg.sender);
        uint256 addedSun;
        (bool isSuccess,bytes memory data) = executeTransaction(poolAddr, 0, "tokenToTrxTransferOutput(uint256,uint256,uint256,address)", abi.encode(trx_bought,dx[1],deadline,msg.sender));
        require(isSuccess,"wrong traction");
        dx[2]=(erc20(token).balanceOf(address(this))).sub(dx[0]);
        if(dx[2]>0){
            require(TransferHelper.safeTransfer(token,msg.sender,dx[2]),"wrong transfer");
        }
        if (isSuccess) {
            addedSun = abi.decode(data, (uint256));
        }
        return addedSun;
    }

    function tokenToTrxTransferOutput(address token,uint256 trx_bought, uint256 max_tokens, uint256 deadline, address payable recipient) public nonReentrant returns (uint256) {
        address payable poolAddr=v1(v1Foctroy).getExchange(token);
        if(approveToken[token][poolAddr]==false){
            TransferHelper.safeApprove(token,poolAddr,maxNum);
            approveToken[token][poolAddr]=true;
        }

        uint256[3] memory dx;
        dx[0]=erc20(token).balanceOf(address(this));
        require(TransferHelper.safeTransferFrom(token,msg.sender,address(this),max_tokens),"wrong transfer");
        dx[1]=(erc20(token).balanceOf(address(this))).sub(dx[0]);

        uint256 addedSun;
        (bool isSuccess,bytes memory data) = executeTransaction(poolAddr, 0, "tokenToTrxTransferOutput(uint256,uint256,uint256,address)", abi.encode(trx_bought,dx[1],deadline,recipient));
        dx[2]=(erc20(token).balanceOf(address(this))).sub(dx[0]);
        if(dx[2]>0){
            require(TransferHelper.safeTransfer(token,msg.sender,dx[2]),"wrong transfer");
        }
        require(isSuccess,"wrong traction");
        if (isSuccess) {
            addedSun = abi.decode(data, (uint256));
        }
        return addedSun;

    }
}




