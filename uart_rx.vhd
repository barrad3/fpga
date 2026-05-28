library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
    generic (
        CLK_FREQ  : integer := 100_000_000;
        BAUD_RATE : integer := 9_600
    );
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        rx         : in  std_logic;
        data_out   : out std_logic_vector(7 downto 0);
        data_valid : out std_logic
    );
end entity;

architecture rtl of uart_rx is

    constant BIT_TICKS      : integer := CLK_FREQ / BAUD_RATE;
    constant HALF_BIT_TICKS : integer := BIT_TICKS / 2;

    type state_t is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    signal state : state_t := IDLE;

    signal tick_count : integer range 0 to BIT_TICKS := 0;
    signal bit_index  : integer range 0 to 7 := 0;

    signal shift_reg : std_logic_vector(7 downto 0) := (others => '0');

    -- 2-stage synchronizer to prevent metastability on async rx input
    signal rx_sync1 : std_logic := '1';
    signal rx_sync2 : std_logic := '1';

begin

    -- Synchronizer process
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                rx_sync1 <= '1';
                rx_sync2 <= '1';
            else
                rx_sync1 <= rx;
                rx_sync2 <= rx_sync1;
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then

            if rst = '1' then
                state      <= IDLE;
                tick_count <= 0;
                bit_index  <= 0;
                shift_reg  <= (others => '0');
                data_out   <= (others => '0');
                data_valid <= '0';

            else
                data_valid <= '0';

                case state is

                    when IDLE =>
                        tick_count <= 0;
                        bit_index  <= 0;

                        -- UART w stanie spoczynku ma RX = '1'.
                        -- Start transmisji to przejście na '0'.
                        if rx_sync2 = '0' then
                            state <= START_BIT;
                        end if;

                    when START_BIT =>
                        -- Czekamy pół bitu i sprawdzamy, czy dalej jest start bit.
                        if tick_count = HALF_BIT_TICKS then
                            if rx_sync2 = '0' then
                                tick_count <= 0;
                                state <= DATA_BITS;
                            else
                                state <= IDLE;
                            end if;
                        else
                            tick_count <= tick_count + 1;
                        end if;

                    when DATA_BITS =>
                        if tick_count = BIT_TICKS - 1 then
                            tick_count <= 0;

                            -- UART wysyła dane od najmłodszego bitu, czyli LSB first.
                            shift_reg(bit_index) <= rx_sync2;

                            if bit_index = 7 then
                                bit_index <= 0;
                                state <= STOP_BIT;
                            else
                                bit_index <= bit_index + 1;
                            end if;
                        else
                            tick_count <= tick_count + 1;
                        end if;

                    when STOP_BIT =>
                        if tick_count = BIT_TICKS - 1 then
                            tick_count <= 0;
                            data_out <= shift_reg;
                            data_valid <= '1';
                            state <= IDLE;
                        else
                            tick_count <= tick_count + 1;
                        end if;

                end case;
            end if;
        end if;
    end process;

end architecture;
