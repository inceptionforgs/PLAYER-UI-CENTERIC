                    "releasePlayback" -> {
                        takeMicFocus()
                        result.success(true)
                    }
                    "restorePlayback" -> {
                        dropMicFocus()
                        result.success(true)
                    }