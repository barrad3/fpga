library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx_tb is
end entity;

architecture sim of uart_rx_tb is

    constant CLK_FREQ  : integer := 100_000_000;
    constant BAUD_RATE : integer := 115_200;
    constant CLK_PERIOD : time := 10 ns;
    constant BIT_TICKS  : integer := CLK_FREQ / BAUD_RATE;
    constant BIT_TIME   : time := CLK_PERIOD * BIT_TICKS;

    signal clk        : std_logic := '0';
    signal rst        : std_logic := '0';
    signal rx         : std_logic := '1'; -- idle high
    signal data_out   : std_logic_vector(7 downto 0);
    signal data_valid : std_logic;

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
        wait for BIT_TIME;
    end procedure;

begin

    uut : entity work.uart_rx
        generic map (
            CLK_FREQ  => CLK_FREQ,
            BAUD_RATE => BAUD_RATE
        )
        port map (
            clk        => clk,
            rst        => rst,
            rx         => rx,
            data_out   => data_out,
            data_valid => data_valid
        );

    clk <= not clk after CLK_PERIOD / 2;

    stim_proc : process
    begin

        -- RESET
        rst <= '1';
        wait for 200 ns;
        rst <= '0';
        wait for 200 ns;

        ----------------------------------------------------------------
        -- TEST 1: Receive 0x41 ('A')
        ----------------------------------------------------------------
        report "UART_RX TEST 1: Sending 0x41";
        send_uart_byte(rx, x"41");

        -- data_valid pulsuje na 1 takt po stop bicie
        wait for CLK_PERIOD * 5;

        assert data_out = x"41"
            report "ERROR: data_out /= 0x41, got " & integer'image(to_integer(unsigned(data_out)))
            severity failure;

        report "UART_RX TEST 1: OK";
        wait for BIT_TIME;

        ----------------------------------------------------------------
        -- TEST 2: Receive 0xA5
        ----------------------------------------------------------------
        report "UART_RX TEST 2: Sending 0xA5";
        send_uart_byte(rx, x"A5");

        wait for CLK_PERIOD * 5;

        assert data_out = x"A5"
            report "ERROR: data_out /= 0xA5"
            severity failure;

        report "UART_RX TEST 2: OK";
        wait for BIT_TIME;

        ----------------------------------------------------------------
        -- TEST 3: Receive 0x00
        ----------------------------------------------------------------
        report "UART_RX TEST 3: Sending 0x00";
        send_uart_byte(rx, x"00");

        wait for CLK_PERIOD * 5;

        assert data_out = x"00"
            report "ERROR: data_out /= 0x00"
            severity failure;

        report "UART_RX TEST 3: OK";
        wait for BIT_TIME;

        ----------------------------------------------------------------
        -- TEST 4: Receive 0xFF
        ----------------------------------------------------------------
        report "UART_RX TEST 4: Sending 0xFF";
        send_uart_byte(rx, x"FF");

        wait for CLK_PERIOD * 5;

        assert data_out = x"FF"
            report "ERROR: data_out /= 0xFF"
            severity failure;

        report "UART_RX TEST 4: OK";
        wait for BIT_TIME;

        ----------------------------------------------------------------
        -- TEST 5: Back-to-back receive
        ----------------------------------------------------------------
        report "UART_RX TEST 5: Back-to-back 0x55 then 0xAA";
        send_uart_byte(rx, x"55");
        wait for CLK_PERIOD * 2;

        assert data_out = x"55"
            report "ERROR: first byte /= 0x55"
            severity failure;

        send_uart_byte(rx, x"AA");
        wait for CLK_PERIOD * 5;

        assert data_out = x"AA"
            report "ERROR: second byte /= 0xAA"
            severity failure;

        report "UART_RX TEST 5: OK";
        wait for BIT_TIME;

        ----------------------------------------------------------------
        -- TEST 6: Reset during reception
        ----------------------------------------------------------------
        report "UART_RX TEST 6: Reset during reception";

        -- Start sending a byte
        rx <= '0'; -- start bit
        wait for BIT_TIME / 2;

        -- Assert reset mid-frame
        rst <= '1';
        wait for 200 ns;
        rst <= '0';

        -- Return to idle
        rx <= '1';
        wait for BIT_TIME * 2;

        -- Now send a valid byte to make sure RX recovered
        send_uart_byte(rx, x"42");
        wait for CLK_PERIOD * 5;

        assert data_out = x"42"
            report "ERROR: data_out after reset /= 0x42"
            severity failure;

        report "UART_RX TEST 6: OK - recovery after reset";

        ----------------------------------------------------------------
        report "ALL UART_RX TESTS PASSED" severity note;
        wait;
    end process;

end architecture;
