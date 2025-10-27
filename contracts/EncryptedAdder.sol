// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*  ▸ Используем ТОЛЬКО официальную библиотеку Zama
 *  ▸ euint8 – зашифрованный uint8, для него разрешены FHE.add/eq/...   */
import {FHE, euint8, externalEuint8} from "@fhevm/solidity/lib/FHE.sol";

/*  ▸ Наследуемся от SepoliaConfig, чтобы контракт «знал» адрес KMS-контракта
 *  ▸ В остальных сетях меняйте на PolygonConfig, MainnetConfig и т.д.        */
import {SepoliaConfig} from "@fhevm/solidity/config/ZamaConfig.sol";

/**
 * @title EncryptedAdder
 * @notice Складывает два euint8 и хранит шифротекст суммы.
 *         Дает права на расшифровку контракту и пользователю-автору вызова.
 */
contract EncryptedAdder is SepoliaConfig {
    /// ciphertext последней суммы
    euint8 private _last;

    /**
     * @dev Homomorphic-сложение.
     * @param a       внешний хендл первого операнда
     * @param b       внешний хендл второго операнда
     * @param proof   ZK-доказательство целостности (Relayer SDK его делает автоматически)
     * @return sumEnc ciphertext-хендл результата
     */
    function add(externalEuint8 a, externalEuint8 b, bytes calldata proof) external returns (euint8 sumEnc) {
        // 1. Десериализуем внешние хендлы во внутреннее представление
        euint8 _a = FHE.fromExternal(a, proof);
        euint8 _b = FHE.fromExternal(b, proof);

        // 2. Складываем зашифрованные значения
        _last = FHE.add(_a, _b);

        /* 3. ACL (обязательно!)
         *    – контракту: чтобы getLastResult() мог вернуть и другие функции могли читать
         *    – msg.sender: чтобы тот, кто вызывал add(), мог расшифровать через userDecrypt   */
        FHE.allowThis(_last); // то же что FHE.allow(_last, address(this))
        FHE.allow(_last, msg.sender);

        return _last; // отдаем ciphertext-хендл
    }

    /**
     * @notice Возвращает ciphertext последнего результата.
     *         Кто угодно может вызвать, но расшифровать сможет только тот,
     *         кому даны права в `add()` (msg.sender) или если сделали
     *         `FHE.makePubliclyDecryptable(_last)`.
     */
    function getLastResult() external view returns (euint8) {
        return _last;
    }
}
