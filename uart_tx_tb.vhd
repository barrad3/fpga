library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx_tb is
end entity;

architecture sim of uart_tx_tb is

    constant CLK_FREQ   : integer := 100_000_000;
    constant BAUD_RATE  : integer := 9_600;
    constant CLK_PERIOD : time := 10 ns;
    constant BIT_TICKS  : integer := CLK_FREQ / BAUD_RATE;
    constant BIT_TIME   : time := CLK_PERIOD * BIT_TICKS;

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '0';
    signal data_in  : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_start : std_logic := '0';
    signal tx       : std_logic;
    signal tx_busy  : std_logic;

    -- Procedure to read a byte from the TX line (same as in top_tb)
    procedure read_uart_byte(
        signal tx_line : in  std_logic;
        variable data  : out std_logic_vector(7 downto 0)
    ) is
    begin
        -- Wait for START bit (line goes low)
        if tx_line /= '0' then
            wait until tx_line = '0';
        end if;

        -- Wait 1.5 bit times to sample middle of first data bit
        wait for BIT_TIME + BIT_TIME / 2;

        -- Read 8 data bits, LSB first
        for i in 0 to 7 loop
            data(i) := tx_line;
            wait for BIT_TIME;
        end loop;

        -- Verify STOP bit
        assert tx_line = '1'
            report "ERROR: Missing STOP bit"
            severity failure;

        wait for BIT_TIME / 2;
    end procedure;

begin

    uut : entity work.uart_tx
        generic map (
            CLK_FREQ  => CLK_FREQ,
            BAUD_RATE => BAUD_RATE
        )
        port map (
            clk      => clk,
            rst      => rst,
            data_in  => data_in,
            tx_start => tx_start,
            tx       => tx,
            tx_busy  => tx_busy
        );

    clk <= not clk after CLK_PERIOD / 2;

    stim_proc : process
        variable received : std_logic_vector(7 downto 0);
    begin

        -- RESET
        rst <= '1';
        wait for 200 ns;
        rst <= '0';
        wait for 200 ns;

        -- Verify idle state
        assert tx = '1'
            report "ERROR: TX should be HIGH (idle) after reset"
            severity failure;
        assert tx_busy = '0'
            report "ERROR: tx_busy should be 0 after reset"
            severity failure;

        ----------------------------------------------------------------
        -- TEST 1: Transmit 0x41 ('A')
        ----------------------------------------------------------------
        report "UART_TX TEST 1: Transmit 0x41";
        data_in <= x"41";
        tx_start <= '1';
        wait for CLK_PERIOD;
        tx_start <= '0';

        -- Read what TX sends
        read_uart_byte(tx, received);

        assert received = x"41"
            report "ERROR: received /= 0x41, got " & integer'image(to_integer(unsigned(received)))
            severity failure;

        -- Wait for TX to finish and become idle
        if tx_busy /= '0' then
            wait until tx_busy = '0';
        end if;
        wait for CLK_PERIOD * 2;

        report "UART_TX TEST 1: OK";

        ----------------------------------------------------------------
        -- TEST 2: Transmit 0xA5
        ----------------------------------------------------------------
        report "UART_TX TEST 2: Transmit 0xA5";
        data_in <= x"A5";
        tx_start <= '1';
        wait for CLK_PERIOD;
        tx_start <= '0';

        read_uart_byte(tx, received);

        assert received = x"A5"
            report "ERROR: received /= 0xA5"
            severity failure;

        if tx_busy /= '0' then
            wait until tx_busy = '0';
        end if;
        wait for CLK_PERIOD * 2;

        report "UART_TX TEST 2: OK";

        ----------------------------------------------------------------
        -- TEST 3: Transmit 0x00
        ----------------------------------------------------------------
        report "UART_TX TEST 3: Transmit 0x00";
        data_in <= x"00";
        tx_start <= '1';
        wait for CLK_PERIOD;
        tx_start <= '0';

        read_uart_byte(tx, received);

        assert received = x"00"
            report "ERROR: received /= 0x00"
            severity failure;

        if tx_busy /= '0' then
            wait until tx_busy = '0';
        end if;
        wait for CLK_PERIOD * 2;

        report "UART_TX TEST 3: OK";

        ----------------------------------------------------------------
        -- TEST 4: Transmit 0xFF
        ----------------------------------------------------------------
        report "UART_TX TEST 4: Transmit 0xFF";
        data_in <= x"FF";
        tx_start <= '1';
        wait for CLK_PERIOD;
        tx_start <= '0';

        read_uart_byte(tx, received);

        assert received = x"FF"
            report "ERROR: received /= 0xFF"
            severity failure;

        if tx_busy /= '0' then
            wait until tx_busy = '0';
        end if;
        wait for CLK_PERIOD * 2;

        report "UART_TX TEST 4: OK";

        ----------------------------------------------------------------
        -- TEST 5: Back-to-back transmit
        ----------------------------------------------------------------
        report "UART_TX TEST 5: Back-to-back 0x55 then 0xAA";

        data_in <= x"55";
        tx_start <= '1';
        wait for CLK_PERIOD;
        tx_start <= '0';

        read_uart_byte(tx, received);
        assert received = x"55"
            report "ERROR: first byte /= 0x55"
            severity failure;

        if tx_busy /= '0' then
            wait until tx_busy = '0';
        end if;
        wait for CLK_PERIOD * 2;

        data_in <= x"AA";
        tx_start <= '1';
        wait for CLK_PERIOD;
        tx_start <= '0';

        read_uart_byte(tx, received);
        assert received = x"AA"
            report "ERROR: second byte /= 0xAA"
            severity failure;

        if tx_busy /= '0' then
            wait until tx_busy = '0';
        end if;
        wait for CLK_PERIOD * 2;

        report "UART_TX TEST 5: OK";

        ----------------------------------------------------------------
        -- TEST 6: tx_start ignored while busy
        ----------------------------------------------------------------
        report "UART_TX TEST 6: tx_start ignored while busy";

        data_in <= x"12";
        tx_start <= '1';
        wait for CLK_PERIOD;
        tx_start <= '0';

        -- While TX is busy, try to start another transmission
        wait for BIT_TIME * 3; -- mid-frame
        data_in <= x"34";
        tx_start <= '1';
        wait for CLK_PERIOD;
        tx_start <= '0';

        -- Should still receive the first byte (0x12)
        read_uart_byte(tx, received);
        assert received = x"12"
            report "ERROR: busy-ignored test failed, got " & integer'image(to_integer(unsigned(received)))
            severity failure;

        if tx_busy /= '0' then
            wait until tx_busy = '0';
        end if;
        wait for CLK_PERIOD * 2;

        report "UART_TX TEST 6: OK";

        ----------------------------------------------------------------
        report "ALL UART_TX TESTS PASSED" severity note;
        wait;
    end process;

end architecture;
