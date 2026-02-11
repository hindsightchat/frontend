package main

import (
	"fmt"
	"time"

	listener "hindsightchat/rpc_hyjacker/src"

	richpresence "github.com/hindsightchat/rpc-reader/src"
)

func main() {
	client := listener.NewIpcClient(listener.DefaultPort)

	isConnected := false

	for !isConnected {
		err := client.Connect()
		if err != nil {
			fmt.Printf("Failed to connect: %v\n", err)
			fmt.Println("Make sure the Flutter app is running first.")
			fmt.Println("Retrying in 5 seconds...")
			time.Sleep(5 * time.Second)
		} else {
			isConnected = true
		}
	}
	defer client.Close()

	rp := richpresence.New()

	rp.Start()

	var oldPresenceUpdate richpresence.PresenceUpdate

	rp.OnPresence(func(update richpresence.PresenceUpdate) {
		if update.ClientID == "" {
			// send
			// No client ID means no presence, skip sending
			return
		}
		fmt.Printf("Received presence update: %+v\n", update)
		if oldPresenceUpdate.ClientID == update.ClientID && oldPresenceUpdate.Activity == update.Activity {
			// No change in presence, skip sending
			return
		}
		oldPresenceUpdate = update
		formattedActivity := listener.Activity{
			Details:    update.Activity.Details,
			State:      update.Activity.State,
			LargeText:  update.Activity.Assets.LargeText,
			SmallText:  update.Activity.Assets.SmallText,
			LargeImage: update.Activity.Assets.LargeImage,
			SmallImage: update.Activity.Assets.SmallImage,
			StartTime:  update.Activity.Timestamps.Start,
			EndTime:    update.Activity.Timestamps.End,
		}

		if err := client.SendActivity(formattedActivity); err != nil {
			fmt.Printf("Failed to send activity: %v\n", err)
			return
		}
	})

	// run forever
	select {}

}
