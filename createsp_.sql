CREATE PROCEDURE sp_ProcessShipment(IN in_pXMLBODY TEXT, OUT perrorCode INT)
main: BEGIN
    
    DECLARE v_reference VARCHAR(25);
    DECLARE checkReference INT DEFAULT 0;
    
    
    DECLARE v_totalPalete_xml INT;
    DECLARE v_totalPKG_xml INT;
    DECLARE v_countPLT_actual INT;
    DECLARE v_countPKG_actual INT;
    
    
    DECLARE v_shipmentID INT;
    DECLARE v_totalItems INT;  -- count
    DECLARE i INT DEFAULT 1; 
    
    
    DECLARE v_item_type VARCHAR(3);
    DECLARE v_item_length, v_item_width, v_item_height DECIMAL(10, 2);

    SET v_reference = ExtractValue(in_pXMLBODY, '/Body/reference');
    
    SELECT COUNT(*) INTO checkReference FROM SHIPMENT WHERE ref = v_reference;
    
    IF checkReference > 0 THEN
        SET perrorCode = 100; -- Erro: Referência já existe
        LEAVE main;
    END IF;

    SET v_totalPalete_xml = ExtractValue(in_pXMLBODY, '/Body/totalPalete');
    SET v_totalPKG_xml = ExtractValue(in_pXMLBODY, '/Body/totalPKG');
    
    
    SET v_countPLT_actual = ExtractValue(in_pXMLBODY, 'count(/Body/items[type="PLT"])');
    SET v_countPKG_actual = ExtractValue(in_pXMLBODY, 'count(/Body/items[type="PKG"])');

    -- Compara os valores declarados com os valores contados
    IF (v_totalPalete_xml != v_countPLT_actual) OR (v_totalPKG_xml != v_countPKG_actual) THEN
        SET perrorCode = 1000; -- Erro: A contagem de itens não corresponde aos totais
        LEAVE main;
    END IF;

    START TRANSACTION;
    
    -- Insere na tabela principal SHIPMENT
    INSERT INTO SHIPMENT (ref, creation_date) VALUES (v_reference, NOW());
    SET v_shipmentID = LAST_INSERT_ID(); -- Guarda o ID do novo registo
    
    -- Conta o número total de itens para o loop
    SET v_totalItems = ExtractValue(in_pXMLBODY, 'count(/Body/items)');
    
    -- Loop para percorrer cada nó <items> e inseri-lo
    WHILE i <= v_totalItems DO
        -- Extrai os dados do i-ésimo item usando XPath dinâmico
        SET v_item_type   = ExtractValue(in_pXMLBODY, CONCAT('/Body/items[', i, ']/type'));
        SET v_item_length = ExtractValue(in_pXMLBODY, CONCAT('/Body/items[', i, ']/length'));
        SET v_item_width  = ExtractValue(in_pXMLBODY, CONCAT('/Body/items[', i, ']/width'));
        SET v_item_height = ExtractValue(in_pXMLBODY, CONCAT('/Body/items[', i, ']/height'));
        
        -- Insere o item na tabela SHIPMENT_ITEMS
        INSERT INTO SHIPMENT_ITEMS (shipment_id, item_type, length, width, height)
        VALUES (v_shipmentID, v_item_type, v_item_length, v_item_width, v_item_height);
        
        SET i = i + 1;
    END WHILE;
    
    COMMIT;
    
    SET perrorCode = 0; -- Sucesso!

END$$

DELIMITER ;

