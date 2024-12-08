contract MiningCFA {
    address public issuer;                // Эмитент ЦФА
    address public custodian;             // Спец счет или аккаунт банка/платформы
    uint256 public softcap;               // Минимальный объем в рублях
    uint256 public hardcap;               // Максимальный объем в рублях
    uint256 public startSubscription;     // Время начала приема заявок (timestamp)
    uint256 public endSubscription;       // Время окончания приема заявок (timestamp)
    bool public issuanceDone;             // Выпуск совершен
    bool public redemptionDone;           // Погашение совершено
    
    // Структура заявки инвестора
    struct Subscription {
        uint256 amount;  // сумма в рублях заявки
        bool    active;  
    }
    
    mapping(address => Subscription) public subscriptions; // заявки инвесторов
    address[] public investorList; 
    
    uint256 public totalRaised;   // общая сумма, собранная по заявкам
    uint256 public totalCFA;      // общее количество выпущенных ЦФА
    mapping(address => uint256) public CFA_balanceOf; 
   
    // Параметры для расчетов
    uint256 public N = 1000;   // номинал ЦФА
    uint256 public R = 1;      // процентная ставка (1%)
    uint256 public CMK;        // Цена компьютера для майнинга
    uint256 public UR;         // курс доллара к рублю (обновляется ораклом)
    uint256 public avgCryptoPrice; // Среднемесячная цена криптовалюты (обновляется ораклом)
    uint256 public monthlyDistributionCount; // Счетчик месяцев для выплат

    modifier onlyIssuer() {
        require(msg.sender == issuer, "Not issuer");
        _;
    }

    modifier onlyCustodian() {
        require(msg.sender == custodian, "Not custodian");
        _;
    }

    constructor(
        address _issuer,
        address _custodian,
        uint256 _softcap,
        uint256 _hardcap,
        uint256 _startSubscription,
        uint256 _endSubscription,
        uint256 _CMK,
        uint256 _UR
    ) {
        issuer = _issuer;
        custodian = _custodian;
        softcap = _softcap;
        hardcap = _hardcap;
        startSubscription = _startSubscription;
        endSubscription = _endSubscription;
        CMK = _CMK;
        UR = _UR;
    }

    // Инвестор вносит средства (рубли) через централизованную систему, 
    // а на смарт-контракт передается информация через custodian (отражаем условно)
    function registerSubscription(address investor, uint256 amount) external onlyCustodian {
        require(block.timestamp >= startSubscription && block.timestamp <= endSubscription, "Not in subscription period");
        require(!issuanceDone, "Already issued");
        require(totalRaised + amount <= hardcap, "Hardcap reached");
        
        if(!subscriptions[investor].active) {
            investorList.push(investor);
            subscriptions[investor].active = true;
        }
        subscriptions[investor].amount += amount;
        totalRaised += amount;
        
        // Если hardcap достигнут раньше времени, можно инициировать выпуск
        if(totalRaised == hardcap) {
            issueCFA();
        }
    }
    
    // Ручной вызов окончания периода подписки в случае недостижения hardcap
    function finalizeSubscription() external onlyIssuer {
        require(block.timestamp > endSubscription, "Subscription not ended");
        require(!issuanceDone, "Already issued");
        issueCFA();
    }
    
    function issueCFA() internal {
        if(totalRaised < softcap) {
            // Возврат средств инвесторам
            for (uint i = 0; i < investorList.length; i++) {
                address inv = investorList[i];
                uint256 amt = subscriptions[inv].amount;
                // Возврат через custodian (банк)
                // emit event или вызов внешнего API через оракул
            }
            issuanceDone = true;
        } else {
            // Распределение ЦФА пропорционально внесенным средствам
            // Предположим, что 1 ЦФА = N рублей по номиналу (упрощение)
            // В реальности объем ЦФА будет определен заранее или по другой формуле
            // Допустим totalCFA = totalRaised / N
            totalCFA = totalRaised / N;
            
            for (uint i = 0; i < investorList.length; i++) {
                address inv = investorList[i];
                uint256 share = (subscriptions[inv].amount * totalCFA) / totalRaised;
                CFA_balanceOf[inv] = share;
            }
            
            issuanceDone = true;
            // Перечисление средств эмитенту через custodian
            // Открытие вторичного рынка - в реальности реализуется отдельным модулем (DEX или P2P)
        }
    }
    
    // Функция для оракула обновить цены (курс криптовалюты, курс доллара)
    function updateMarketData(uint256 _avgCryptoPrice, uint256 _UR) external onlyCustodian {
        avgCryptoPrice = _avgCryptoPrice;
        UR = _UR;
    }
    
    // Ежемесячный расчет выплат инвесторам
    // Для упрощения - ручной вызов эмитентом после обновления данных о ценах
    function monthlyPayout() external onlyIssuer {
        require(issuanceDone, "Not issued");
        require(!redemptionDone, "Already redeemed");
        
        // Расчет средней доходности
        // СДК = П*ЦК*UR (П - производительность, ЦК - avgCryptoPrice, UR - текущий курс USD/RUB)
        // Предположим П известна (допустим П = 1 условная единица)
        uint256 P = 1; 
        uint256 CDK = P * avgCryptoPrice * UR;
        
        // ЕПк = СДК/(ЦМК/N)*R*КВ
        // КВ = totalCFA, R = 1%, N = 1000
        // ЦМК и N известны из контракта
        // ЕПк - общий платеж эмитента
        // Но нам нужно распределение по инвесторам. Для каждого инвестора доход будет:
        // ДИ = (СДК/(ЦМК/N))*R*M
        // где M - количество ЦФА у инвестора.
        
        // Для упрощения: сначала считаем общий платеж, затем делим на основе долей.
        // ЕПк = (СДК/(CMK/N))*R*totalCFA
        // Подставим R = 1% = 0.01 (в реальности через bigNumber)
        uint256 numerator = (CDK * N * R) / 100; // Условно R=1%, значит делим на 100
        // Сначала так: (СДК/(CMK/N)) = СДК * N / CMK
        // ЕПк = (СДК * N / CMK)*R*totalCFA
        uint256 ЕПк = ((CDK * N) / CMK) * totalCFA / 100; // Так как R=1% = /100
        
        // Перечисление инвесторам (в реальности - через custodian)
        // Тут просто пример: event или внутренний учет, реальных средств нет.
        for (uint i = 0; i < investorList.length; i++) {
            address inv = investorList[i];
            uint256 invCFA = CFA_balanceOf[inv];
            uint256 invPayment = (((CDK * N) / CMK) * invCFA) / 100; 
            // Вызов внешней системы для перечисления invPayment инвестору
        }
        
        monthlyDistributionCount++;
    }
    
    // Погашение ЦФА
    // По аналогии с ежемесячным расчетом, но в конце срока
    function redeemCFA() external onlyIssuer {
        require(!redemptionDone, "Already redeemed");
        // Логика похожа на ежемесячный расчет, плюс возврат номинала
        // Рассчитать последний платеж, затем вернуть номинал (CFA_balanceOf[inv]*N)
        
        for (uint i = 0; i < investorList.length; i++) {
            address inv = investorList[i];
            uint256 invCFA = CFA_balanceOf[inv];
            if(invCFA > 0) {
                uint256 redemptionAmount = invCFA * N; 
                // Перечисление redemptionAmount инвестору через custodian
                // Обнулить баланс ЦФА
                CFA_balanceOf[inv] = 0;
            }
        }
        
        redemptionDone = true;
    }
}
