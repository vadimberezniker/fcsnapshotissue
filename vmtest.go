package main

import (
	"fmt"
	"log"
	"runtime/debug"
	"time"
)

func memoryCheck() error {
	buffer := make([]byte, 1024*1024*2)
	for i := 0; i < len(buffer); i++ {
		buffer[i] = byte(i % 256)
	}
	for i := 0; i < len(buffer); i++ {
		exp := byte(i % 256)
		if buffer[i] != exp {
			return fmt.Errorf("data at %d did not match, expected %d got %d", i, exp, buffer[i])
		}
	}
	return nil
}

func memoryCheckLoop() {
	log.Printf("Starting memory test...")
	start := time.Now()
	for {
		for i := 0; i < 256; i++ {
			if err := memoryCheck(); err != nil {
				log.Printf("Error: %s", err)
			}
		}
		log.Printf("Memory loop completed, time since start %s", time.Now().Sub(start))
		debug.FreeOSMemory()
	}
}

func main() {
	log.Printf("Starting test.")

	go memoryCheckLoop()

	select {}
}
