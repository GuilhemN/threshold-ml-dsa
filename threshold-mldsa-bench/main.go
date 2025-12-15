package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"threshold-mldsa/sign"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run main.go type= iter= t= n=")
		os.Exit(1)
	}

	if len(os.Args) > 6 {
		fmt.Println("Only five args are allowed")
		os.Exit(1)
	}

	args := make(map[string]string)
	for _, arg := range os.Args[1:] {
		parts := strings.SplitN(arg, "=", 2)
		if len(parts) != 2 {
			fmt.Printf("Invalid argument format: %s\n", arg)
			os.Exit(1)
		}
		args[parts[0]] = parts[1]
	}

	partyID, ok := args["type"]
	if !ok {
		fmt.Println("Missing type parameter.")
		os.Exit(1)
	}

	iterStr, ok := args["iter"]
	if !ok {
		fmt.Println("Missing iter parameter.")
		os.Exit(1)
	}

	t, ok := args["t"]
	if !ok {
		fmt.Println("Missing t parameter.")
		os.Exit(1)
	}

	n, ok := args["n"]
	if !ok {
		fmt.Println("Missing n parameter.")
		os.Exit(1)
	}

	p, ok := args["p"]
	if !ok {
		fmt.Println("Missing p parameter.")
		os.Exit(1)
	}

	var err error
	var iters, threshold, parties, param int
	iters, err = strconv.Atoi(iterStr)
	threshold, err = strconv.Atoi(t)
	parties, err = strconv.Atoi(n)
	param, err = strconv.Atoi(p)
	if err != nil {
		fmt.Println("Error: Please enter a valid integer for params.")
		os.Exit(1)
	}

	if parties > 6 {
		fmt.Println("Only maximum 6 parties are allowed")
		os.Exit(1)
	}

	sign.K = parties
	sign.Threshold = threshold
	sign.Param = param

	if partyID == "d" {
		sign.LocalThresholdDilithiumRun(iters)
		return
	}
}
