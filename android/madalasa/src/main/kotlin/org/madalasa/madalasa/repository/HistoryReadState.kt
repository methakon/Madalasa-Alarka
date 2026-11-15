package org.madalasa.madalasa.repository

import org.madalasa.madalasa.api.FreeChildHistory

data class HistoryReadState(
    val data: FreeChildHistory? = null,
    val status: String = "History not loaded. Select a child and refresh."
)
