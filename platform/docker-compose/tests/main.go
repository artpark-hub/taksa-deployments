package main

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/nats-io/nats.go"
	"github.com/nats-io/nats.go/jetstream"
)

const (
	defaultURL     = "nats://localhost:4222"
	testSubject    = "test.subject"
	testMessage    = "Hello NATS from Go!"
	streamName     = "TEST_STREAM_GO"
	consumerName   = "TEST_CONSUMER_GO"
	jsSubject      = "test.subject.js"
	requestSubject = "test.subject.request"
	timeout        = 5 * time.Second
)

// Color codes for terminal output
const (
	colorReset  = "\033[0m"
	colorRed    = "\033[31m"
	colorGreen  = "\033[32m"
	colorYellow = "\033[33m"
	colorBlue   = "\033[34m"
)

func main() {
	fmt.Println("\n==========================================")
	fmt.Println("  NATS/JetStream Go Test Program")
	fmt.Println("==========================================\n")

	// Get configuration from environment
	url := getEnv("NATS_URL", defaultURL)
	user := os.Getenv("NATS_USER")
	password := os.Getenv("NATS_PASSWORD")

	// Connect to NATS
	nc, err := connectNATS(url, user, password)
	if err != nil {
		logError("Failed to connect to NATS: %v", err)
		os.Exit(1)
	}
	defer nc.Close()

	failedTests := 0

	// Run tests
	if !testConnectivity(nc) {
		failedTests++
	}
	fmt.Println()

	if !testBasicPubSub(nc) {
		failedTests++
	}
	fmt.Println()

	if !testRequestReply(nc) {
		failedTests++
	}
	fmt.Println()

	if !testJetStream(nc) {
		failedTests++
	}
	fmt.Println()

	// Summary
	fmt.Println("==========================================")
	if failedTests == 0 {
		logSuccess("All tests passed! ✓")
	} else {
		logError("%d test(s) failed", failedTests)
	}
	fmt.Println("==========================================\n")

	if failedTests > 0 {
		os.Exit(1)
	}
}

// connectNATS establishes connection to NATS server
func connectNATS(url, user, password string) (*nats.Conn, error) {
	logInfo("Connecting to NATS server at %s...", url)

	opts := []nats.Option{
		nats.Name("NATS Go Test Client"),
		nats.Timeout(timeout),
	}

	// Add authentication if provided
	if user != "" && password != "" {
		opts = append(opts, nats.UserInfo(user, password))
		logInfo("Using authentication (user: %s)", user)
	}

	nc, err := nats.Connect(url, opts...)
	if err != nil {
		return nil, err
	}

	logSuccess("Connected to NATS server")
	logInfo("Server Info: %s", nc.ConnectedServerName())
	return nc, nil
}

// testConnectivity tests basic connectivity
func testConnectivity(nc *nats.Conn) bool {
	logInfo("Testing connectivity...")

	if !nc.IsConnected() {
		logError("Not connected to NATS server")
		return false
	}

	stats := nc.Stats()
	logSuccess("Connection test passed")
	logInfo("In Msgs: %d, Out Msgs: %d, In Bytes: %d, Out Bytes: %d",
		stats.InMsgs, stats.OutMsgs, stats.InBytes, stats.OutBytes)
	return true
}

// testBasicPubSub tests basic publish/subscribe functionality
func testBasicPubSub(nc *nats.Conn) bool {
	logInfo("Testing basic pub/sub functionality...")

	// Create a channel to receive messages
	msgChan := make(chan *nats.Msg, 1)

	// Subscribe
	sub, err := nc.Subscribe(testSubject, func(msg *nats.Msg) {
		msgChan <- msg
	})
	if err != nil {
		logError("Failed to subscribe: %v", err)
		return false
	}
	defer sub.Unsubscribe()

	// Flush to ensure subscription is processed
	nc.Flush()

	// Give subscription time to be established
	time.Sleep(100 * time.Millisecond)

	logInfo("Subscribed to subject: %s", testSubject)

	// Publish message
	logInfo("Publishing message: '%s'", testMessage)
	err = nc.Publish(testSubject, []byte(testMessage))
	if err != nil {
		logError("Failed to publish: %v", err)
		return false
	}

	// Wait for message with timeout
	select {
	case msg := <-msgChan:
		receivedMsg := string(msg.Data)
		if receivedMsg == testMessage {
			logSuccess("Pub/Sub test passed - message received: '%s'", receivedMsg)
			return true
		}
		logError("Received wrong message: '%s'", receivedMsg)
		return false
	case <-time.After(2 * time.Second):
		logError("Timeout waiting for message")
		return false
	}
}

// testRequestReply tests request/reply pattern
func testRequestReply(nc *nats.Conn) bool {
	logInfo("Testing request/reply pattern...")

	// Set up reply handler
	sub, err := nc.Subscribe(requestSubject, func(msg *nats.Msg) {
		response := fmt.Sprintf("Response to: %s", string(msg.Data))
		msg.Respond([]byte(response))
	})
	if err != nil {
		logError("Failed to subscribe for replies: %v", err)
		return false
	}
	defer sub.Unsubscribe()

	// Flush to ensure subscription is processed
	nc.Flush()
	time.Sleep(100 * time.Millisecond)

	logInfo("Reply handler listening on: %s", requestSubject)

	// Send request
	requestMsg := "ping"
	logInfo("Sending request: '%s'", requestMsg)
	msg, err := nc.Request(requestSubject, []byte(requestMsg), 2*time.Second)
	if err != nil {
		logError("Request failed: %v", err)
		return false
	}

	response := string(msg.Data)
	logSuccess("Request/Reply test passed - received: '%s'", response)
	return true
}

// testJetStream tests JetStream functionality
func testJetStream(nc *nats.Conn) bool {
	logInfo("Testing JetStream functionality...")

	// Create JetStream context
	js, err := jetstream.New(nc)
	if err != nil {
		logError("Failed to create JetStream context: %v", err)
		return false
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Clean up any existing stream
	js.DeleteStream(ctx, streamName)

	// Create stream
	if !createStream(ctx, js) {
		return false
	}

	// Publish messages to stream
	if !publishToStream(ctx, js) {
		return false
	}

	// Create consumer and consume messages
	if !consumeFromStream(ctx, js) {
		return false
	}

	// Clean up
	logInfo("Cleaning up test stream...")
	js.DeleteStream(ctx, streamName)

	logSuccess("JetStream test completed successfully")
	return true
}

// createStream creates a JetStream stream
func createStream(ctx context.Context, js jetstream.JetStream) bool {
	logInfo("Creating JetStream stream: %s", streamName)

	streamConfig := jetstream.StreamConfig{
		Name:      streamName,
		Subjects:  []string{jsSubject + ".*"},
		Storage:   jetstream.MemoryStorage,
		Retention: jetstream.LimitsPolicy,
		MaxMsgs:   -1,
		MaxBytes:  -1,
		MaxAge:    0,
		Replicas:  1,
	}

	stream, err := js.CreateStream(ctx, streamConfig)
	if err != nil {
		logError("Failed to create stream: %v", err)
		return false
	}

	logSuccess("Stream created: %s", stream.CachedInfo().Config.Name)
	return true
}

// publishToStream publishes messages to JetStream
func publishToStream(ctx context.Context, js jetstream.JetStream) bool {
	logInfo("Publishing messages to stream...")

	messageCount := 5
	for i := 1; i <= messageCount; i++ {
		subject := fmt.Sprintf("%s.msg%d", jsSubject, i)
		message := fmt.Sprintf("JetStream Message %d", i)

		ack, err := js.Publish(ctx, subject, []byte(message))
		if err != nil {
			logError("Failed to publish message %d: %v", i, err)
			return false
		}

		logInfo("Published message %d - Stream: %s, Sequence: %d",
			i, ack.Stream, ack.Sequence)
	}

	logSuccess("Published %d messages to stream", messageCount)
	return true
}

// consumeFromStream creates a consumer and consumes messages
func consumeFromStream(ctx context.Context, js jetstream.JetStream) bool {
	logInfo("Creating consumer: %s", consumerName)

	stream, err := js.Stream(ctx, streamName)
	if err != nil {
		logError("Failed to get stream: %v", err)
		return false
	}

	// Get stream info
	info, err := stream.Info(ctx)
	if err != nil {
		logError("Failed to get stream info: %v", err)
		return false
	}
	logInfo("Stream has %d messages", info.State.Msgs)

	// Create consumer
	consumerConfig := jetstream.ConsumerConfig{
		Name:          consumerName,
		Durable:       consumerName,
		AckPolicy:     jetstream.AckExplicitPolicy,
		FilterSubject: jsSubject + ".*",
		DeliverPolicy: jetstream.DeliverAllPolicy,
	}

	consumer, err := stream.CreateOrUpdateConsumer(ctx, consumerConfig)
	if err != nil {
		logError("Failed to create consumer: %v", err)
		return false
	}

	logSuccess("Consumer created: %s", consumer.CachedInfo().Name)

	// Consume messages
	logInfo("Consuming messages...")
	msgCount := 0
	maxMessages := 5

	messages, err := consumer.Fetch(maxMessages)
	if err != nil {
		logError("Failed to fetch messages: %v", err)
		return false
	}

	for msg := range messages.Messages() {
		msgCount++
		metadata, _ := msg.Metadata()
		logInfo("Received message %d - Subject: %s, Sequence: %d, Data: %s",
			msgCount, msg.Subject(), metadata.Sequence.Stream, string(msg.Data()))

		// Acknowledge the message
		if err := msg.Ack(); err != nil {
			logError("Failed to ack message: %v", err)
			return false
		}

		if msgCount >= maxMessages {
			break
		}
	}

	if msgCount == 0 {
		logError("No messages consumed")
		return false
	}

	logSuccess("Successfully consumed %d messages from stream", msgCount)
	return true
}

// Utility functions
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func logInfo(format string, args ...interface{}) {
	fmt.Printf("%s[INFO]%s ", colorBlue, colorReset)
	fmt.Printf(format+"\n", args...)
}

func logSuccess(format string, args ...interface{}) {
	fmt.Printf("%s[SUCCESS]%s ", colorGreen, colorReset)
	fmt.Printf(format+"\n", args...)
}

func logError(format string, args ...interface{}) {
	fmt.Printf("%s[ERROR]%s ", colorRed, colorReset)
	fmt.Printf(format+"\n", args...)
}

func logWarning(format string, args ...interface{}) {
	fmt.Printf("%s[WARNING]%s ", colorYellow, colorReset)
	fmt.Printf(format+"\n", args...)
}
