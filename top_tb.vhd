library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_tb is
end entity;

architecture sim of top_tb is

    constant CLK_PERIOD : time := 10 ns; -- 100 MHz

    -- Dla UART 115200:
    -- 100_000_000 / 115_200 = 868 taktów
    constant BIT_TICKS : integer := 100_000_000 / 115_200;
    constant BIT_TIME  : time := CLK_PERIOD * BIT_TICKS;

    signal clk    : std_logic := '0';
    signal btnC   : std_logic := '0';

    -- UART idle state = '1'
    signal ble_rx  : std_logic := '1';
    signal ble_tx  : std_logic;
    signal ble_cts : std_logic;

    signal led    : std_logic_vector(7 downto 0);

    procedure send_uart_byte(
        signal rx_line : out std_logic;
        data           : in  std_logic_vector(7 downto 0)
    ) is
    begin
        -- START bit
        rx_line <= '0';
        wait for BIT_TIME;

        -- DATA bits, LSB first
        for i in 0 to 7 loop
            rx_line <= data(i);
            wait for BIT_TIME;
        end loop;

        -- STOP bit
        rx_line <= '1';

        -- Nie czekamy całego stop bitu,
        -- żeby nie przegapić początku echa na ble_tx.
        wait for BIT_TIME / 4;
    end procedure;


    procedure read_uart_byte(
        signal tx_line : in std_logic;
        variable data  : out std_logic_vector(7 downto 0)
    ) is
    begin
        -- Czekamy na START bit, czyli przejście TX na 0
        if tx_line /= '0' then
            wait until tx_line = '0';
        end if;

        -- Start bit trwa 1 BIT_TIME.
        -- Potem czekamy jeszcze pół bitu, żeby być w środku bitu danych nr 0.
        wait for BIT_TIME + BIT_TIME / 2;

        -- Odczyt 8 bitów danych, LSB first
        for i in 0 to 7 loop
            data(i) := tx_line;
            wait for BIT_TIME;
        end loop;

        -- Teraz powinien być STOP bit = 1
        assert tx_line = '1'
            report "ERROR: Brak poprawnego STOP bitu na ble_tx"
            severity failure;

        wait for BIT_TIME / 2;
    end procedure;

begin

    --------------------------------------------------------------------
    -- Instancja testowanego modułu
    --------------------------------------------------------------------
    uut : entity work.top
        port map (
            clk     => clk,
            btnC    => btnC,
            ble_rx  => ble_rx,
            ble_tx  => ble_tx,
            ble_cts => ble_cts,
            led     => led
        );

    --------------------------------------------------------------------
    -- Generator zegara 100 MHz
    --------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2;


    --------------------------------------------------------------------
    -- Główny proces testujący
    --------------------------------------------------------------------
    stim_proc : process
        variable echo_data : std_logic_vector(7 downto 0);
    begin

        -- RESET
        btnC <= '1';
        wait for 200 ns;
        btnC <= '0';
        wait for 200 ns;


        ----------------------------------------------------------------
        -- TEST 1: wysyłamy znak ASCII 'A' = 0x41
        ----------------------------------------------------------------
        report "TEST 1: Wysylam bajt 0x41 (ASCII 'A')";

        send_uart_byte(ble_rx, x"41");

        -- Najpierw czytamy echo, żeby nie przegapić początku ramki ble_tx
        read_uart_byte(ble_tx, echo_data);

        assert echo_data = x"41"
            report "ERROR: Echo nie jest rowne 0x41"
            severity failure;

        -- LED-y sprawdzamy dopiero teraz, bo wtedy na pewno zdążyły się ustawić
        assert led = x"41"
            report "ERROR: LED-y nie pokazuja 0x41"
            severity failure;

        report "TEST 1: OK - Echo=0x41, LED=0x41";
        wait for BIT_TIME;


        ----------------------------------------------------------------
        -- TEST 2: wysyłamy 0xA5
        ----------------------------------------------------------------
        report "TEST 2: Wysylam bajt 0xA5";

        send_uart_byte(ble_rx, x"A5");

        read_uart_byte(ble_tx, echo_data);

        assert echo_data = x"A5"
            report "ERROR: Echo nie jest rowne 0xA5"
            severity failure;

        assert led = x"A5"
            report "ERROR: LED-y nie pokazuja 0xA5"
            severity failure;

        report "TEST 2: OK - Echo=0xA5, LED=0xA5";
        wait for BIT_TIME;


        ----------------------------------------------------------------
        -- TEST 3: wysyłamy 0xFF
        ----------------------------------------------------------------
        report "TEST 3: Wysylam bajt 0xFF";

        send_uart_byte(ble_rx, x"FF");

        read_uart_byte(ble_tx, echo_data);

        assert echo_data = x"FF"
            report "ERROR: Echo nie jest rowne 0xFF"
            severity failure;

        assert led = x"FF"
            report "ERROR: LED-y nie pokazuja 0xFF"
            severity failure;

        report "TEST 3: OK - Echo=0xFF, LED=0xFF";
        wait for BIT_TIME;


        ----------------------------------------------------------------
        -- TEST 4: wysyłamy 0x00
        ----------------------------------------------------------------
        report "TEST 4: Wysylam bajt 0x00";

        send_uart_byte(ble_rx, x"00");

        read_uart_byte(ble_tx, echo_data);

        assert echo_data = x"00"
            report "ERROR: Echo nie jest rowne 0x00"
            severity failure;

        assert led = x"00"
            report "ERROR: LED-y nie pokazuja 0x00"
            severity failure;

        report "TEST 4: OK - Echo=0x00, LED=0x00";
        wait for BIT_TIME;


        ----------------------------------------------------------------
        -- Koniec testów
        ----------------------------------------------------------------
        report "WSZYSTKIE TESTY PRZESZLY POPRAWNIE" severity note;

        wait;
    end process;

end architecture;
