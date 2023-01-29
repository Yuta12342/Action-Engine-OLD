#include <iostream>
#include <ogg/ogg.h>
#include <vorbis/codec.h>

int main() {
  // Open the OGG file
  FILE* file = fopen("example.ogg", "rb");
  if (file == nullptr) {
    std::cerr << "Failed to open OGG file" << std::endl;
    return 1;
  }

  // Read the OGG file
  ogg_sync_state sync_state;
  ogg_sync_init(&sync_state);
  ogg_page page;
  while (ogg_sync_pageout(&sync_state, &page) != 1) {
    char* buffer = ogg_sync_buffer(&sync_state, 4096);
    int bytes_read = fread(buffer, 1, 4096, file);
    ogg_sync_wrote(&sync_state, bytes_read);
  }

  // Extract the BPM information from the Vorbis metadata packet
  ogg_stream_state stream_state;
  ogg_stream_init(&stream_state, ogg_page_serialno(&page));
  vorbis_info info;
  vorbis_comment comment;
  vorbis_info_init(&info);
  vorbis_comment_init(&comment);
  ogg_packet packet;
  while (ogg_stream_packetout(&stream_state, &packet) != 0) {
    vorbis_synthesis_headerin(&info, &comment, &packet);
  }
  double bpm = -1;
  for (int i = 0; i < comment.comments; i++) {
    if (strncmp(comment.user_comments[i], "BPM=", 4) == 0) {
      bpm = atof(comment.user_comments[i] + 4);
      break;
    }
  }

  // Print the BPM information
  if (bpm < 0) {
    std::cout << "BPM information not found" << std::endl;
  } else {
    std::cout << "BPM: " << bpm << std::endl;
  }

  // Clean up
  fclose(file);
  vorbis_info_clear(&info);
  vorbis_comment_clear(&comment);
  ogg_stream_clear(&stream_state);
  ogg_sync_clear(&sync_state);
  return 0;
}
