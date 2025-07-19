CREATE DEFINER=`root`@`localhost` PROCEDURE `trest_create_manifest`(IN dadosXML LONGTEXT,
OUT perrorCode INT,
OUT pMessage VARCHAR(255)
)
main:BEGIN

    /*
    Exemplo de XML esperado:
    <Body>
        <manifestSendDate>2025-07-01</manifestSendDate>
        <manifestDetails>
            <Name>Ivo</Name>
            <Dest>Braga</Dest>
        </manifestDetails>
        <manifestDetails>
            <Name>Paulo</Name>
            <Dest>Porto</Dest>
        </manifestDetails>
    </Body>
    */

    -- Declaração de variáveis
    DECLARE v_node_count INT DEFAULT 0;
    DECLARE i INT DEFAULT 1;
    DECLARE v_ship_id INT;
    DECLARE v_name VARCHAR(255);
    DECLARE v_dest VARCHAR(255);
    DECLARE v_idsForManifest TEXT DEFAULT '';
    DECLARE v_error_messages TEXT DEFAULT ''; -- Nova variável para acumular erros
    DECLARE v_name_exists INT DEFAULT 0;

    -- Inicializa os parâmetros de saída.
    SET perrorCode = 0;
    SET pMessage = '';

    -- 1. Contar quantos nós <manifestDetails> existem no XML.
    SET v_node_count = ExtractValue(dadosXML, 'count(/Body/manifestDetails)');

    -- Se não houver nenhum nó para processar, define uma mensagem de erro e sai.
    IF v_node_count = 0 THEN
        SET perrorCode = 114;
        SET pMessage = CONCAT('Erro: XML nao contem a tag <manifestDetails> ou esta mal formatado.');
        LEAVE main;
    END IF;

    -- 2. Inicia um loop para percorrer cada nó <manifestDetails>.
    WHILE i <= v_node_count DO
        -- Reseta as variáveis a cada iteração do loop.
        SET v_name = NULL;
        SET v_dest = NULL;
        SET v_ship_id = NULL;

        -- 3. Extrai os valores de 'Name' e 'Dest' do nó atual.
        SET v_name = ExtractValue(dadosXML, '/Body/manifestDetails[$i]/Name');
        SET v_dest = ExtractValue(dadosXML, '/Body/manifestDetails[$i]/Dest');

        -- 4. Valida se o registo existe.
        SELECT COUNT(*) INTO v_name_exists
        FROM ship_headers
        WHERE Name = v_name;

        IF v_name_exists = 0 THEN
            -- Se o nome não existe, acumula a mensagem de erro.
            SET v_error_messages = CONCAT(v_error_messages, 'Erro: O Name ''', v_name, ''' nao foi encontrado; ');
        ELSE
            -- Se o nome existe, procuramos a combinação exata para obter o ID.
            SELECT id INTO v_ship_id
            FROM ship_headers
            WHERE Name = v_name AND Dest = v_dest
            LIMIT 1;

            IF v_ship_id IS NULL THEN
                -- Se a combinação não existe, acumula a mensagem de erro.
                SET v_error_messages = CONCAT(v_error_messages, 'Erro: O Name ''', v_name, ''' existe, mas o Dest ''', v_dest, ''' nao corresponde; ');
            ELSE
                -- SUCESSO: Se a combinação foi encontrada, concatena o ID.
                IF v_idsForManifest = '' THEN
                    SET v_idsForManifest = CAST(v_ship_id AS CHAR);
                ELSE
                    SET v_idsForManifest = CONCAT(v_idsForManifest, ',', CAST(v_ship_id AS CHAR));
                END IF;
            END IF;
        END IF;

        -- Incrementa o contador do loop.
        SET i = i + 1;
    END WHILE;

    -- 7. Processar resultados após o loop.
    IF v_idsForManifest != '' THEN
        -- Inserir os IDs válidos se houver algum.
        INSERT INTO manifest (shipIDs) VALUES (v_idsForManifest);
    END IF;

    -- 8. Construir a mensagem final de saída.
    IF v_error_messages = '' THEN
        -- Sucesso total
        SET perrorCode = 0;
        SET pMessage = CONCAT('Manifesto criado com sucesso. IDs inseridos: ', v_idsForManifest);
    ELSE
        -- Houve erros.
        IF v_idsForManifest != '' THEN
            -- Sucesso parcial
            SET perrorCode = 1; -- Código para sucesso parcial
            SET pMessage = CONCAT('Processamento parcial. Inseridos: ', v_idsForManifest, '. Erros: ', v_error_messages);
        ELSE
            -- Falha total (nenhum ID válido)
            SET perrorCode = 113;
            SET pMessage = CONCAT('Nenhum registo válido encontrado. Erros: ', v_error_messages);
        END IF;
    END IF;

END main
