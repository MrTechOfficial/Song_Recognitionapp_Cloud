3297
3298
3299
3300
3301
3302
3303
3304
3305
3306
3307
3308
3309
3310
3311
3312
3313
3314
3315
3316
3317
3318
3319
3320
3321
3322
3323
3324
3325
3326
3327
3328
3329
3330
3331
3332
3333
3334
3335
3336
3337
3338
3339
3340
3341
3342
3343
3344
3345
3346
3347
3348
3349
3350
3351
3352
3353
3354
3355
3356
3357
3358
3359
3360
3361
3362
3363
3364
3365
3366
3367
3368
3369
3370
3371
3372
3373
3374
3375
3376
3377
3378
3379
3380
3381
3382
3383
3384
3385
3386
3387
3388
3389
3390
3391
3392
3393
3394
3395
3396
3397
3398
3399
3400
3401
3402
3403
3404
3405
3406
3407
3408
3409
3410
3411
                    or top_selection < environment_floor
                    or background_is_ambiguous
                ):
                    return {
                        "success": False,
                        "message": (
                            "Queued recording is not yet strong enough for "
                            "unattended recognition."
                        ),
                        "retryable": True,
                        "background_queue": True,
                    }
            else:
                # Avoid the worst user experience: confidently auto-playing one
                # weak, unsupported guess. If there are two plausible choices,
                # return them so Flutter can ask "first or second" / show Top Guesses.
                base_floor = {
                    "quiet": 0.37 if auto_play_requested else 0.32,
                    "loud": 0.40 if auto_play_requested else 0.34,
                    "outdoors": 0.42 if auto_play_requested else 0.36,
                }.get(environment, 0.40)

                if evidence_count >= 2 or acr_votes >= 2:
                    base_floor -= 0.035

                has_plausible_alternative = (
                    second_selection is not None and second_selection >= 0.28
                )

                if top_selection < base_floor and not has_plausible_alternative:
                    return {
                        "success": False,
                        "message": (
                            "Recognition confidence was too low. Try the same "
                            "melody again a little more clearly."
                        ),
                        "retryable": True,
                    }

            # Auto Play should speak "first or second" only when the secondary
            # candidate is itself playable as a verified canonical track. The top
            # recognized result is never removed, and no score/order is changed.
            client_results = results
            if auto_play_requested and results:
                # Every candidate offered to the hands-free chooser must be
                # independently playable. If at least one verified direct link
                # exists, omit unverified choices rather than asking the user to
                # select a song that cannot then Auto Play. If none can be
                # verified, preserve the top recognition result for display.
                # Collapse close same-title alternatives before requiring a
                # verified playback URL. This lets a candidate from the expanded
                # enrichment pool win the same-title tiebreak even if it was not
                # initially in the top three playback-link lookups.
                collapsed_results = collapse_same_title_autoplay_choices(results)

                # Resolve playback for the actual choices we may return. Existing
                # top-three resolutions are reused; only a newly promoted choice
                # needs an additional lookup.
                for candidate in collapsed_results[:3]:
                    if not candidate.get("playback_link_verified"):
                        attach_direct_canonical_playback_links(candidate, language)

                verified_results = [
                    candidate
                    for candidate in collapsed_results
                    if candidate.get("playback_link_verified")
                ]
                client_results = verified_results or [collapsed_results[0]]

            # Backward-compatible top-level fields plus a scored candidate list.
            # recognition_meta intentionally contains no transcript/audio content.
            response: Dict[str, Any] = {
                "success": True,
                "title": top.get("title", ""),
                "artist": top.get("artist", ""),
                "spotify_url": top.get("spotify_url", ""),
                "apple_music_url": top.get("apple_music_url", ""),
                "confidence": top.get("confidence"),
                "selection_score": top.get("selection_score"),
                "genre": top.get("genre", ""),
                "cover_url": top.get("cover_url", ""),
                "source": top.get("source", ""),
                "recognition_type": top.get("recognition_type", acr_kind),
                "results": client_results[:3],
                "recognition_meta": {
                    "pipeline_version": "3.2",
                    "environment": environment,
                    "acr_passes_attempted": acr_meta.get("passes_attempted", 0),
                    "acr_passes_with_candidates": acr_meta.get(
                        "passes_with_candidates",
                        0,
                    ),
                    "acr_top_votes": acr_meta.get("top_votes", 0),
                    "lyric_crosscheck_used": should_crosscheck_lyrics,
                    "groq_models_attempted": len(
                        groq_meta.get("attempted_models") or []
                    ),
                    "groq_secondary_audio_used": bool(
                        groq_meta.get("used_secondary_audio")
                    ),
                    "vocal_isolation_requested": vocal_isolation_requested,
                },
            }
            return response

        except HTTPException:
            raise
        except Exception as exc:
            print(f"[SERVER ERROR] {type(exc).__name__}: {exc}")
            raise HTTPException(
                status_code=500,
                detail="Recognition server error",
            ) from exc

