package listener

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"time"
)

const DefaultPort = 19542

type IpcClient struct {
	conn net.Conn
	port int
}

type ActivityPayload struct {
	Type     string   `json:"type"`
	Activity Activity `json:"activity,omitempty"`
}

type Activity struct {
	Details    string `json:"details,omitempty"`
	State      string `json:"state,omitempty"`
	LargeText  string `json:"large_text,omitempty"`
	SmallText  string `json:"small_text,omitempty"`
	LargeImage string `json:"large_image,omitempty"`
	SmallImage string `json:"small_image,omitempty"`
	StartTime  int64  `json:"start_time,omitempty"`
	EndTime    int64  `json:"end_time,omitempty"`
}

func NewIpcClient(port int) *IpcClient {
	if port == 0 {
		port = DefaultPort
	}
	return &IpcClient{
		port: port,
	}
}

func (c *IpcClient) Connect() error {
	addr := fmt.Sprintf("127.0.0.1:%d", c.port)

	conn, err := net.DialTimeout("tcp", addr, 5*time.Second)
	if err != nil {
		return fmt.Errorf("failed to connect to %s: %w", addr, err)
	}

	c.conn = conn
	fmt.Printf("[ipc-client] connected to %s\n", addr)
	return nil
}

func (c *IpcClient) Close() error {
	if c.conn != nil {
		return c.conn.Close()
	}
	return nil
}

func (c *IpcClient) Send(data []byte) error {
	if c.conn == nil {
		return fmt.Errorf("not connected")
	}

	data = append(data, '\n')
	_, err := c.conn.Write(data)
	if err != nil {
		return fmt.Errorf("failed to write: %w", err)
	}

	fmt.Printf("[ipc-client] sent: %s", string(data))
	return nil
}

func (c *IpcClient) SendString(msg string) error {
	return c.Send([]byte(msg))
}

func (c *IpcClient) SendJSON(v any) error {
	data, err := json.Marshal(v)
	if err != nil {
		return fmt.Errorf("failed to marshal: %w", err)
	}
	return c.Send(data)
}

func (c *IpcClient) SendActivity(activity Activity) error {
	payload := ActivityPayload{
		Type:     "activity_update",
		Activity: activity,
	}
	return c.SendJSON(payload)
}

func (c *IpcClient) ClearActivity() error {
	return c.SendJSON(map[string]string{"type": "activity_clear"})
}

func (c *IpcClient) Read() ([]byte, error) {
	if c.conn == nil {
		return nil, fmt.Errorf("not connected")
	}

	reader := bufio.NewReader(c.conn)
	data, err := reader.ReadBytes('\n')
	if err != nil {
		return nil, err
	}

	return data, nil
}

func (c *IpcClient) StartReading(callback func([]byte)) {
	go func() {
		for {
			data, err := c.Read()
			if err != nil {
				fmt.Printf("[ipc-client] read error: %v\n", err)
				return
			}
			callback(data)
		}
	}()
}
