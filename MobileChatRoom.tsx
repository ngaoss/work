// import React, { useState, useEffect, useRef, useCallback } from 'react';
// import { useParams, useNavigate } from 'react-router-dom';
// import {
//   Send, X, ImageIcon, Smile, Loader2,
//   ChevronLeft, MoreVertical, Check, Reply, Camera, LogOut, Trash2, Edit2,
//   Plus, Search, UserPlus, StickyNote,
//   FileUp,
//   FileText,
//   ChevronUp,
//   ChevronDown,
//   Play,
//   Download,
//   ListChecks
// } from 'lucide-react';
// import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
// import { vscDarkPlus } from 'react-syntax-highlighter/dist/esm/styles/prism';
// import { io, Socket } from 'socket.io-client';
// import { useAuth } from '../context/AuthContext';
// import { API_BASE, apiFetch } from '@/config/api';
// import { format } from 'path';

// const THEMES = ['#2563eb', '#db2777', '#7c3aed', '#059669', '#ea580c', '#334155', '#ef4444'];
// const EMOJIS = ['😊', '😂', '😍', '🤣', '😘', '😭', '😮', '😢', '😡', '👍', '❤️', '🔥', '🙌', '🎉', '🚀', '🤔', '✨', '💯'];
// import { toast } from 'react-hot-toast';
// import {
//   File,
//   Image,
//   Video,
//   FileArchive,
//   FileSpreadsheet,
// } from "lucide-react";

// // 🎯 Detect file type
// const getFileIcon = (fileName = "") => {
//   const ext = fileName.split(".").pop()?.toLowerCase();

//   switch (ext) {
//     case "pdf":
//       return <FileText className="text-red-500 shrink-0" size={24} />;
//     case "doc":
//     case "docx":
//       return <FileText className="text-blue-600 shrink-0" size={24} />;
//     case "xls":
//     case "xlsx":
//       return <FileSpreadsheet className="text-green-600 shrink-0" size={24} />;
//     case "png":
//     case "jpg":
//     case "jpeg":
//     case "gif":
//       return <Image className="text-purple-500 shrink-0" size={24} />;
//     case "mp4":
//     case "mov":
//     case "avi":
//       return <Video className="text-orange-500 shrink-0" size={24} />;
//     case "zip":
//     case "rar":
//       return <FileArchive className="text-yellow-600 shrink-0" size={24} />;
//     default:
//       return <File className="text-gray-500 shrink-0" size={24} />;
//   }
// };


// const renderContentWithLinks = (text: string, isMe: boolean) => {
//   if (!text) return null;

//   // 1. Kiểm tra xem có phải là Code không
//   const isCode = /const |let |var |function |def |import |public |class |#include|print\(|=>|\{.*\}|\[.*\]|;\s*$/m.test(text);

//   if (isCode) {
//     return (
//       <div className="my-2 rounded-xl overflow-hidden text-[12px] w-full">
//         <SyntaxHighlighter
//           language="javascript"
//           style={vscDarkPlus}
//           customStyle={{ margin: 0, padding: '1rem', borderRadius: '0.75rem' }}
//         >
//           {text}
//         </SyntaxHighlighter>
//       </div>
//     );
//   }

//   // 2. Xử lý Link bình thường
//   const urlRegex = /(https?:\/\/[^\s]+|www\.[^\s]+)/g;
//   const parts = text.split(urlRegex);

//   return (
//     <div className="whitespace-pre-wrap break-words leading-relaxed">
//       {parts.map((part, i) => {
//         if (part.match(urlRegex)) {
//           return (
//             <a key={i} href={part.startsWith('http') ? part : `https://${part}`} target="_blank" rel="noopener noreferrer"
//               onClick={(e) => e.stopPropagation()}
//               className={`font-bold underline decoration-2 underline-offset-2 ${isMe ? 'text-white' : 'text-[#3366E3]'}`}>
//               {part}
//             </a>
//           );
//         }
//         return <span key={i}>{part}</span>;
//       })}
//     </div>
//   );
// };


// const STICKERS = [
//   "https://media.giphy.com/media/l0HlBO7eyXzSZkJri/giphy.gif",
//   "https://media.giphy.com/media/26gsspfbt1HfVQ9va/giphy.gif",
//   "https://media.giphy.com/media/111ebonMs90YLu/giphy.gif",
//   "https://media.giphy.com/media/3o7abGQa0aRJUurpII/giphy.gif",
//   "https://media.giphy.com/media/3o6wrvdHFbwBrUFenu/giphy.gif",
//   "https://media.giphy.com/media/ROF8OQvDmxytW/giphy.gif",
//   "https://media.giphy.com/media/OPU6wzx8JrHna/giphy.gif",
//   "https://media.giphy.com/media/3o6ZsZwgkWKohM8kp2/giphy.gif",
//   "https://media.giphy.com/media/10JhviFuU2gWD6/giphy.gif",
//   "https://media.giphy.com/media/26n6WywJyh39n1pBu/giphy.gif",
//   "https://media.giphy.com/media/l0ExncehJzexFpRHq/giphy.gif",
//   "https://media.giphy.com/media/xT9IgG50Fb7Mi0prBC/giphy.gif",
//   "https://media.giphy.com/media/3oEduSbSGpGaRX2Vri/giphy.gif",
//   "https://media.giphy.com/media/1BXa2alBjrCXC/giphy.gif"
// ];


// const isCode = (str: string) => {
//   // Thêm các dấu hiệu nhận biết mạnh mẽ hơn
//   const codePatterns = [
//     /\{[\s\S]*\}/,       // Có cặp ngoặc nhọn
//     /function|const|let|var|import|export|=>/, // Từ khóa
//     /console\.log|if\s*\(|return\s+/,
//     /;\s*$/m             // Có dấu chấm phẩy ở cuối dòng
//   ];
//   return codePatterns.some(pattern => pattern.test(str));
// };

// const isCodeOnly = (str: string) => {
//   if (!str) return false;
//   // Các từ khóa lập trình phổ biến
//   const codeKeywords = [
//     'const ', 'let ', 'var ', 'function ', '=>', 'import ', 'export ',
//     'console.log', 'if (', 'return ', 'class ', 'interface ', 'useState', 'useEffect'
//   ];
//   // Các dấu hiệu đặc trưng: chứa cặp ngoặc {} hoặc [] hoặc dấu chấm phẩy ;
//   const hasCodeSigns = /\{[\s\S]*\}|\[[\s\S]*\]|;\s*$/m.test(str);

//   return codeKeywords.some(kw => str.includes(kw)) || hasCodeSigns;
// };


// const MobileChatRoom: React.FC = () => {
//   const { convId } = useParams<{ convId: string }>();

//   console.log("convID:", convId);



//   // 2. Trong MobileChatRoom Component:
//   const [chatFiles, setChatFiles] = useState<ChatDocument[]>([]);
//   const [filesPage, setFilesPage] = useState(1);
//   const [hasMoreFiles, setHasMoreFiles] = useState(true);

//   const [fileSearch, setFileSearch] = useState('');
//   const fetchChatFiles = useCallback(async (pageNum: number) => {
//     if (!convId) return;

//     try {
//       const res = await apiFetch(`/api/documents/chat/${convId}?page=${pageNum}&limit=10`, {
//         method: 'GET',
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': `Bearer ${localStorage.getItem('token')}`
//         }
//       });

//       const data = await res.json();
//       console.log("DEBUG: Data tài liệu:", data);

//       if (res.ok) {
//         // Vì API trả về { documents: [...], hasMore: boolean }
//         const docs = data.documents || [];

//         setChatFiles(prev => pageNum === 1 ? docs : [...prev, ...docs]);
//         setHasMoreFiles(data.hasMore);
//         setFilesPage(pageNum);
//       }
//     } catch (e) {
//       console.error("Lỗi fetch tài liệu:", e);
//     }
//   }, [convId]);


//   const handleDownload = (file: any) => {
//     console.log("DEBUG [Download]: Bắt đầu xử lý file:", file.name);

//     const token = localStorage.getItem('token');
//     console.log("DEBUG [Download]: Token đang sử dụng:", token ? "Đã tìm thấy token" : "LỖI: KHÔNG TÌM THẤY TOKEN!");

//     if (!token) {
//       alert("Bạn chưa đăng nhập hoặc token đã hết hạn!");
//       return;
//     }

//     // Tạo URL download
//     const downloadUrl = `${API_BASE}/api/documents/download/${file._id}?token=${token}`;
//     console.log("DEBUG [Download]: URL hoàn chỉnh:", downloadUrl);

//     // Tạo thẻ <a>
//     const link = document.createElement('a');
//     link.href = downloadUrl;
//     link.setAttribute('download', file.name || 'file');
//     link.setAttribute('target', '_blank');

//     console.log("DEBUG [Download]: Đang kích hoạt click link...");

//     document.body.appendChild(link);
//     link.click();
//     document.body.removeChild(link);
//   };

//   const navigate = useNavigate();
//   const { user: currentUser } = useAuth();
//   // Translation States
//   const [translatedMessages, setTranslatedMessages] = useState<Record<string, string>>({});
//   const [isTranslating, setIsTranslating] = useState<Record<string, boolean>>({});
//   // --- STATES ---
//   const [messages, setMessages] = useState<any[]>([]);
//   const [inputValue, setInputValue] = useState('');
//   const [convData, setConvData] = useState<any>(null);
//   const [loading, setLoading] = useState(true);
//   const [isRemoteTyping, setIsRemoteTyping] = useState(false);
//   const [page, setPage] = useState(1);
//   const [hasMore, setHasMore] = useState(true);
//   const [isFetchingMore, setIsFetchingMore] = useState(false);
//   const [activeOverlay, setActiveOverlay] = useState<'settings' | 'emoji' | 'stickers' | 'survey' | 'none'>('none');
//   const [isEditingName, setIsEditingName] = useState(false);
//   const [tempName, setTempName] = useState('');
//   const [isUpdating, setIsUpdating] = useState(false);
//   const [isAddingMember, setIsAddingMember] = useState(false);
//   const [allUsers, setAllUsers] = useState<any[]>([]);
//   const [searchUser, setSearchUser] = useState('');
//   const [selectedFullTimeId, setSelectedFullTimeId] = useState<string | null>(null);
//   const [replyingTo, setReplyingTo] = useState<any>(null);
//   const [hoveredReactionMsgId, setHoveredReactionMsgId] = useState<string | null>(null);

//   const scrollRef = useRef<HTMLDivElement>(null);
//   const socketRef = useRef<Socket | null>(null);
//   const groupAvatarInputRef = useRef<HTMLInputElement>(null);
//   const isInitialLoad = useRef(true);

//   const [isOpenMembers, setIsOpenMembers] = useState(true);
//   const [isOpenFiles, setIsOpenFiles] = useState(true);
//   const [fullScreenMedia, setFullScreenMedia] = useState<any>(null);


//   const [surveyQuestion, setSurveyQuestion] = useState('');
//   const [surveyOptions, setSurveyOptions] = useState(['', '']); // Mặc định 2 lựa chọn


//   // Gọi fetch khi mở overlay settings
//   useEffect(() => {
//     if (activeOverlay === 'settings') {
//       fetchChatFiles(1);
//     }
//   }, [activeOverlay, fetchChatFiles]);

//   // const [chatFiles, setChatFiles] = useState<ChatFile[]>(MOCK_FILES);

//   // Thêm vào danh sách state
//   // const [chatFiles, setChatFiles] = useState<any[]>([]);
//   // const [filesPage, setFilesPage] = useState(1);
//   // const [hasMoreFiles, setHasMoreFiles] = useState(true); // <--- THÊM DÒNG NÀY

//   const formatSize = (size: number) => {
//     if (size < 1024) return size + ' B';
//     if (size < 1024 * 1024) return (size / 1024).toFixed(1) + ' KB';
//     return (size / (1024 * 1024)).toFixed(1) + ' MB';
//   };


//   const getAuthHeaders = useCallback(() => ({
//     'Content-Type': 'application/json',
//     'Authorization': `Bearer ${localStorage.getItem('token')}`
//   }), []);



//   // 1. Sửa lại hàm scrollToBottom để an toàn hơn
//   const scrollToBottom = useCallback((behavior: ScrollBehavior = 'smooth') => {
//     if (scrollRef.current) {
//       // Sử dụng requestAnimationFrame để đảm bảo đã render xong UI
//       requestAnimationFrame(() => {
//         if (scrollRef.current) {
//           scrollRef.current.scrollTo({
//             top: scrollRef.current.scrollHeight,
//             behavior
//           });
//         }
//       });
//     }
//   }, []);


//   // --- HELPERS ---
//   const formatFullDate = (dateInput: any) => {
//     const d = new Date(dateInput);
//     if (isNaN(d.getTime())) return "N/A";
//     const pad = (n: number) => n.toString().padStart(2, '0');
//     return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
//   };


//   const fetchMessages = useCallback(async (pageNum: number) => {
//     if (!convId) return;
//     try {
//       const res = await apiFetch(`/api/chats/${convId}/messages?page=${pageNum}&limit=20`, { headers: getAuthHeaders() });
//       const data = await res.json();

//       console.log("Message:", data);
//       if (res.ok) {
//         setMessages(prev => pageNum === 1 ? data.messages : [...data.messages, ...prev]);
//         setHasMore(data.hasMore);
//       }
//     } catch (e) { console.error(e); } finally { setLoading(false); setIsFetchingMore(false); }
//   }, [convId, getAuthHeaders]);

//   const fetchConvData = useCallback(async () => {
//     try {
//       const res = await apiFetch(`/api/chats`, { headers: getAuthHeaders() });
//       const all = await res.json();
//       const current = all.find((c: any) => c._id === convId);
//       if (current) { setConvData(current); setTempName(current.name || ''); }
//       else { navigate('/inbox'); }
//     } catch (e) { console.error(e); }
//   }, [convId, getAuthHeaders, navigate]);


//   // Khai báo state
//   const [showReadByPopup, setShowReadByPopup] = useState<{ isOpen: boolean; readers: any[] }>({
//     isOpen: false,
//     readers: []
//   });


//   // Thay vì chỉ có showReadByPopup, hãy đổi tên hoặc tạo state chung
//   const [userListPopup, setUserListPopup] = useState<{
//     isOpen: boolean;
//     users: any[];
//     title: string
//   }>({ isOpen: false, users: [], title: '' });


//   useEffect(() => {
//     if (!convId || !currentUser) return;

//     setLoading(true);

//     const init = async () => {
//       try {
//         // 1. Load data và đánh dấu ĐÃ ĐỌC trên Server
//         await Promise.all([
//           fetchConvData(),
//           fetchMessages(1),
//           apiFetch(`/api/chats/${convId}/read`, { method: 'PUT', headers: getAuthHeaders() })
//         ]);

//         // 2. Khởi tạo Socket
//         const socketInstance = io(API_BASE, {
//           auth: { token: localStorage.getItem('token') },
//           transports: ['websocket'],
//           reconnection: true
//         });

//         socketRef.current = socketInstance;
//         socketInstance.emit('join_new_conversation', convId);

//         // 3. Lắng nghe tin nhắn mới
//         socketInstance.on('new_message', (msg: any) => {
//           if (msg.conversationId === convId) {
//             setMessages(prev => [...prev, msg]);
//             // Sau khi có tin mới, ta gửi tiếp 1 lệnh ĐÃ ĐỌC lên server để báo cho người gửi
//             apiFetch(`/api/chats/${convId}/read`, { method: 'PUT', headers: getAuthHeaders() });
//             setTimeout(() => scrollToBottom('smooth'), 100);
//           }
//         });


//         socketInstance.on('messages_read_updated', (data: { conversationId: string, reader: any }) => {
//           if (data.conversationId === convId) {
//             setMessages(prevMessages =>
//               prevMessages.map(msg => {
//                 // Kiểm tra xem đã có readerId trong danh sách readBy chưa
//                 // Lưu ý: msg.readBy có thể là mảng chứa object (đã populate) hoặc mảng chứa ID
//                 const isAlreadyRead = msg.readBy?.some((u: any) => {
//                   const id = u._id || u;
//                   return id.toString() === data.reader._id.toString();
//                 });

//                 if (!isAlreadyRead) {
//                   return {
//                     ...msg,
//                     // Thêm đối tượng reader đầy đủ vào mảng readBy
//                     readBy: [...(msg.readBy || []), data.reader]
//                   };
//                 }
//                 return msg;
//               })
//             );
//           }
//         });


//         // Lắng nghe cập nhật survey
//         socketRef.current.on('survey_updated', (data: any) => {
//           setMessages(prev => prev.map(m => m._id === data.messageId ? { ...m, survey: data.survey } : m));
//         });


//         // Trong useEffect của MobileChatRoom.tsx
//         socketInstance.on('survey_updated', (data: { messageId: string, survey: any }) => {
//           setMessages(prev => prev.map(msg => {
//             if (msg._id === data.messageId) {
//               return {
//                 ...msg,
//                 survey: data.survey // Cập nhật survey mới nhất, React sẽ render lại cái Thanh tiến trình
//               };
//             }
//             return msg;
//           }));
//         });

//         // 5. Các sự kiện khác
//         socketInstance.on('message_reaction_updated', (data: any) => {
//           setMessages(prev => prev.map(m => m._id === data.messageId ? { ...m, reactions: data.reactions } : m));
//         });

//         socketInstance.on('message_recalled', (data: { messageId: string }) => {
//           setMessages(prev => prev.map(msg => msg._id === data.messageId ? { ...msg, isRecalled: true, text: "Tin nhắn đã được thu hồi", media: [] } : msg));
//         });

//         socketInstance.on('display_typing', (data: any) => {
//           if (data.conversationId === convId && data.userId !== currentUser.id) setIsRemoteTyping(data.isTyping);
//         });

//         socketInstance.on('group_update', (updatedConv: any) => {
//           if (updatedConv._id === convId) setConvData(updatedConv);
//         });

//         setLoading(false);
//         requestAnimationFrame(() => scrollToBottom('auto'));

//       } catch (error) {
//         console.error("Init error:", error);
//         setLoading(false);
//       }
//     };

//     init();

//     return () => {
//       socketRef.current?.disconnect();
//     };
//   }, [convId, fetchConvData, fetchMessages, currentUser?.id, getAuthHeaders]);

//   const goToProfile = (userId: string) => {
//     setShowReadByPopup({ isOpen: false, readers: [] });
//     navigate(`/profile/${userId}`);
//   };

//   const handleSend = async (opts: {
//     text?: string;
//     image?: string;
//     fileUrl?: string;
//     documentId?: string;
//     fileName?: string;
//     survey?: any;
//   }) => {
//     const content = (opts.text || inputValue || "").trim();
//     const image = opts.image;
//     const fileUrl = opts.fileUrl;
//     const survey = opts.survey;

//     // DEBUG LOG 1: Kiểm tra đầu vào của hàm
//     console.log("DEBUG [Send]: Options received:", opts);
//     console.log("DEBUG [Send]: Content:", content);
//     console.log("DEBUG [Send]: Survey Object:", survey ? JSON.stringify(survey, null, 2) : "Không có survey");

//     const hasMedia = !!(image || fileUrl);

//     if ((!content && !hasMedia && !survey) || !convId || !socketRef.current) {
//       console.warn("DEBUG [!] Không thể gửi: Thiếu nội dung hoặc socket chưa sẵn sàng");
//       return;
//     }

//     const mediaPayload = [];
//     if (image) mediaPayload.push({ url: image, type: 'image' });
//     if (fileUrl) {
//       mediaPayload.push({
//         url: fileUrl,
//         type: 'file',
//         documentId: opts.documentId,
//         name: opts.fileName || 'Tài liệu'
//       });
//     }

//     const messagePayload = {
//       conversationId: convId,
//       text: content,
//       media: mediaPayload,
//       survey: survey, // Đính kèm survey object
//       replyTo: replyingTo ? replyingTo._id : null
//     };

//     // DEBUG LOG 2: Kiểm tra cấu trúc payload chuẩn bị gửi qua socket
//     console.log("DEBUG [Socket]: Payload chuẩn bị emit:", JSON.stringify(messagePayload, null, 2));

//     socketRef.current.emit('send_message', messagePayload);

//     socketRef.current.emit('typing', { conversationId: convId, isTyping: false });
//     setInputValue('');
//     setReplyingTo(null);

//     console.log("🚀 [Socket] Đã gửi tin nhắn thành công!");
//   };

//   const handleTranslate = async (msgId: string, text: string) => {
//     // Nếu đã dịch rồi thì không cần gọi lại API
//     if (translatedMessages[msgId]) return;

//     setIsTranslating(prev => ({ ...prev, [msgId]: true }));
//     try {
//       const res = await apiFetch('/api/translate', {
//         method: 'POST',
//         headers: {
//           'Content-Type': 'application/json',
//           // 'Authorization': `Bearer ${localStorage.getItem('token')}` // Nếu API yêu cầu thì để lại, không thì xóa
//         },
//         body: JSON.stringify({
//           text: text,
//           source: "auto", // Để API tự detect ngôn ngữ gốc
//           target: currentUser?.language || "vi" // Sử dụng ngôn ngữ cài đặt của user
//         })
//       });

//       const data = await res.json();

//       if (res.ok) {
//         // API của bạn trả về { "translated": "..." }
//         setTranslatedMessages(prev => ({ ...prev, [msgId]: data.translated }));
//       } else {
//         console.error("Lỗi dịch:", data);
//       }
//     } catch (e) {
//       console.error("Lỗi kết nối dịch:", e);
//     } finally {
//       setIsTranslating(prev => ({ ...prev, [msgId]: false }));
//     }
//   };
//   const handleUploadDocument = async (file: File) => {
//     setIsUpdating(true);

//     // LOG 1: Kiểm tra file
//     console.log("DEBUG [1] File đang upload:", {
//       name: file.name,
//       size: file.size,
//       type: file.type
//     });

//     const formData = new FormData();
//     formData.append('documents', file); // Đảm bảo key 'document' khớp với backend: uploadDocument.single('document')
//     if (convId) formData.append('conversationId', convId);

//     try {
//       const res = await apiFetch('/api/documents/upload', {
//         method: 'POST',
//         headers: { 'Authorization': `Bearer ${localStorage.getItem('token')}` },
//         body: formData
//       });

//       const data = await res.json();
//       console.log("📥 [DEBUG] Server trả về khi upload:", data);


//       if (res.ok) {
//         // 1. Lấy data thô từ backend
//         let fileInfo = data.data || data.document || data;

//         // 2. Nếu là array thì lấy phần tử đầu tiên
//         if (Array.isArray(fileInfo)) {
//           fileInfo = fileInfo.length > 0 ? fileInfo[0] : null;
//         }

//         console.log("🔍 [DEBUG] fileInfo sau normalize:", fileInfo);

//         // 3. Check null
//         if (!fileInfo) {
//           toast.error("Lỗi: Không có dữ liệu file từ server!");
//           return;
//         }

//         // 4. Lấy id + url (cover nhiều case backend)
//         const finalId = fileInfo._id || fileInfo.id;
//         const finalUrl = fileInfo.fileUrl || fileInfo.url || fileInfo.path;

//         console.log("🔍 [DEBUG] Sau khi trích xuất:", { id: finalId, url: finalUrl });

//         // 5. Validate dữ liệu
//         if (!finalId || !finalUrl) {
//           console.error("❌ Thiếu dữ liệu:", fileInfo);
//           toast.error("Lỗi: Server không trả về ID hoặc URL của file!");
//           return;
//         }

//         // 6. Gửi message
//         await handleSend({
//           text: `📎 Đã gửi tài liệu: ${file.name}`,
//           fileUrl: finalUrl,
//           documentId: finalId,
//           fileName: file.name
//         });

//       } else {
//         toast.error(data.message || "Lỗi upload");
//       }


//     } catch (e) {
//       console.error(e);
//       toast.error("Lỗi kết nối server");
//     } finally {
//       setIsUpdating(false);
//     }
//   };


//   const handleScroll = () => {
//     if (!scrollRef.current || isFetchingMore || !hasMore) return;
//     if (scrollRef.current.scrollTop < 50) {
//       setIsFetchingMore(true);
//       const scrollHeightBefore = scrollRef.current.scrollHeight;
//       const nextPage = page + 1;
//       setPage(nextPage);
//       fetchMessages(nextPage).then(() => {
//         setTimeout(() => {
//           if (scrollRef.current) {
//             scrollRef.current.scrollTop = scrollRef.current.scrollHeight - scrollHeightBefore;
//           }
//         }, 50);
//       });
//     }
//   };

//   const handleReactToMessage = async (messageId: string, emoji: string) => {
//     setHoveredReactionMsgId(null);
//     try {
//       await apiFetch(`/api/chats/messages/${messageId}/react`, {
//         method: 'PUT', headers: getAuthHeaders(), body: JSON.stringify({ emoji })
//       });
//     } catch (e) { console.error(e); }
//   };

//   // --- TRÁNH LỖI TRẮNG MÀN HÌNH ---
//   if (loading) return <div className="h-[100dvh] flex items-center justify-center"><Loader2 className="animate-spin w-10 h-10" /></div>;


//   const isGroup = convData?.isGroup;
//   const otherMember = !isGroup ? convData?.participants?.find((p: any) => p._id !== currentUser?.id) : null;
//   const isConversationActive = isGroup ? convData?.participants?.some((p: any) => p._id !== currentUser?.id && p.isOnline) : otherMember?.isOnline;
//   const displayName = isGroup ? convData.name : (otherMember?.fullName || "Hội thoại");
//   const activeTheme = convData?.themeColor || '#2563eb';
//   const isCreator = (convData?.createdBy?._id || convData?.createdBy) === (currentUser?.id || currentUser?._id);

//   const handleDeleteMessage = async (msgId: string) => {
//     if (!window.confirm("Bạn có chắc chắn muốn xóa tin nhắn này?")) return;

//     try {
//       const res = await apiFetch(`/api/chats/messages/${msgId}/recall`, {
//         method: 'PUT',
//         headers: getAuthHeaders()
//       });

//       if (res.ok) {
//         // CẬP NHẬT LOCAL STATE NGAY LẬP TỨC
//         setMessages(prev => prev.map(msg => {
//           if (msg._id === msgId) {
//             return {
//               ...msg,
//               isRecalled: true,
//               text: "Tin nhắn đã được thu hồi",
//               media: []
//             };
//           }
//           return msg;
//         }));
//       } else {
//         alert("Không thể thu hồi tin nhắn");
//       }
//     } catch (e) {
//       console.error("Lỗi xóa tin nhắn:", e);
//     }
//   };
//   // --- QUẢN TRỊ NHÓM LOGIC ---
//   const updateGroupInfo = async (updates: any) => {
//     setIsUpdating(true);
//     try {
//       const res = await apiFetch(`/api/chats/${convId}`, {
//         method: 'PUT', headers: getAuthHeaders(), body: JSON.stringify(updates)
//       });
//       if (res.ok) await fetchConvData();
//     } catch (e) { alert("Lỗi"); }
//     finally { setIsUpdating(false); setIsEditingName(false); }
//   };

//   const handleGroupAvatarChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
//     const file = e.target.files?.[0];
//     if (!file) return;
//     setIsUpdating(true);
//     const formData = new FormData();
//     formData.append('image', file);
//     try {
//       const uploadRes = await apiFetch('/api/images/upload', { method: 'POST', headers: { 'Authorization': `Bearer ${localStorage.getItem('token')}` }, body: formData });
//       const data = await uploadRes.json();
//       if (uploadRes.ok) await updateGroupInfo({ groupAvatar: data.image._id });
//     } catch (err) { alert("Lỗi"); }
//     finally { setIsUpdating(false); }
//   };

//   const fetchUsersToAdd = async () => {
//     try {
//       const res = await apiFetch('/api/users?limit=500', { headers: getAuthHeaders() });
//       const data = await res.json();
//       if (res.ok) {
//         const existingIds = convData.participants.map((p: any) => p._id);
//         setAllUsers((data.users || []).filter((u: any) => !existingIds.includes(u._id)));
//         setIsAddingMember(true);
//       }
//     } catch (e) { console.error(e); }
//   };



//   const handleRemoveMember = async (memberId: string) => {
//     if (!window.confirm("Xoá thành viên?")) return;
//     setIsUpdating(true);
//     try {
//       await apiFetch(`/api/chats/${convId}/remove-member`, { method: 'PUT', headers: getAuthHeaders(), body: JSON.stringify({ memberId }) });
//       await fetchConvData();
//     } catch (e) { alert("Lỗi"); } finally { setIsUpdating(false); }
//   };

//   const handleAddMembers = async (userIds: string[]) => {
//     setIsUpdating(true);
//     try {
//       await apiFetch(`/api/chats/${convId}/add-members`, { method: 'PUT', headers: getAuthHeaders(), body: JSON.stringify({ newUserIds: userIds }) });
//       setIsAddingMember(false);
//       await fetchConvData();
//     } catch (e) { alert("Lỗi"); } finally { setIsUpdating(false); }
//   };

//   const handleLeaveGroup = async () => {
//     if (!window.confirm("Rời khỏi nhóm này?")) return;
//     try {
//       const res = await apiFetch(`/api/chats/${convId}/leave`, { method: 'POST', headers: getAuthHeaders() });
//       if (res.ok) navigate('/inbox');
//     } catch (e) { console.error(e); }
//   };

//   const handleDeleteGroup = async () => {
//     if (!window.confirm("Xoá nhóm vĩnh viễn?")) return;
//     try {
//       const res = await apiFetch(`/api/chats/${convId}`, { method: 'DELETE', headers: getAuthHeaders() });
//       if (res.ok) navigate('/inbox');
//     } catch (e) { console.error(e); }
//   };

//   // --- HELPER QUAN TRỌNG: KIỂM TRA CHỈ CÓ EMOJI ---
//   const isOnlyEmoji = (str: string) => {
//     if (!str) return false;
//     // Regex này kiểm tra chuỗi chỉ chứa emoji và các ký tự đặc biệt liên quan đến emoji
//     const emojiRegex = /^(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff]|[ \t\n\r\f\v])+$/g;
//     return emojiRegex.test(str.trim());
//   };
//   // --- QUẢN TRỊ NHÓM LOGIC ---
//   // 1. Khai báo Interface cho tài liệu
//   interface ChatDocument {
//     _id: string;
//     name: string;
//     mimeType: string;
//     size: number;
//     createdAt: string;
//     fileUrl: string;
//   }



//   const handlePaste = async (e: React.ClipboardEvent<HTMLTextAreaElement>) => {
//     const items = e.clipboardData.items;

//     for (let i = 0; i < items.length; i++) {
//       // Kiểm tra xem item có phải là hình ảnh không
//       if (items[i].type.indexOf('image') !== -1) {
//         const file = items[i].getAsFile();
//         if (file) {
//           e.preventDefault(); // Chặn việc dán code rác vào textarea
//           uploadPastedImage(file);
//         }
//       }
//     }
//   };

//   const uploadPastedImage = async (file: File) => {
//     setIsUpdating(true); // Dùng state loading hiện tại của bạn
//     const formData = new FormData();
//     formData.append('image', file);

//     try {
//       const res = await apiFetch('/api/images/upload', {
//         method: 'POST',
//         headers: { 'Authorization': `Bearer ${localStorage.getItem('token')}` },
//         body: formData
//       });

//       const data = await res.json();
//       if (res.ok) {
//         // Gửi ảnh vừa paste lên khung chat
//         handleSend({
//           image: `${API_BASE}/api/images/${data.image._id}`
//         });
//       } else {
//         alert("Lỗi upload ảnh dán");
//       }
//     } catch (e) {
//       console.error("Lỗi:", e);
//       alert("Có lỗi xảy ra khi xử lý ảnh");
//     } finally {
//       setIsUpdating(false);
//     }
//   };


//   const handleVote = async (messageId: string, optionIndex: number) => {
//     try {
//       await apiFetch(`/api/chats/messages/${messageId}/vote`, {
//         method: 'PUT',
//         headers: { ...getAuthHeaders() },
//         body: JSON.stringify({ optionIndex })
//       });
//     } catch (e) { alert("Lỗi bình chọn"); }
//   };


//   return (
//     <div className="fixed inset-0 h-[100dvh] w-full bg-white flex flex-col overflow-hidden z-[100]">
//       {/* <input type="file" ref={groupAvatarInputRef} className="hidden" accept="image/*" onChange={handleGroupAvatarChange} /> */}
//       {/* <input type="file" ref={groupAvatarInputRef} className="hidden" accept="image/*" onChange={handleGroupAvatarChange} /> */}
//       <input
//         type="file"
//         ref={groupAvatarInputRef}
//         className="hidden"
//         accept="image/*"
//         onChange={handleGroupAvatarChange}
//       />
//       {/* HEADER */}
//       <header className="flex-shrink-0 bg-white border-b border-slate-100 pt-[env(safe-area-inset-top)] z-10 shadow-sm">
//         <div className="h-14 px-2 flex items-center justify-between">
//           <div className="flex items-center gap-1 min-w-0">
//             <button onClick={() => navigate('/inbox')} className="p-2 active:scale-75 transition-all"><ChevronLeft size={28} className="text-slate-900" /></button>
//             <div className="flex items-center gap-2 min-w-0 cursor-pointer" onClick={() => setActiveOverlay('settings')}>
//               <div className="relative shrink-0">
//                 <img src={isGroup ? (convData.groupAvatar ? `${API_BASE}/api/images/${convData.groupAvatar}` : `https://ui-avatars.com/api/?name=${displayName}&background=random`) : (otherMember?.profilePicture ? `${API_BASE}/api/images/${otherMember.profilePicture}` : `https://ui-avatars.com/api/?name=${displayName}&background=random`)} className="w-10 h-10 rounded-full object-cover border border-slate-100 shadow-sm" alt="" />
//                 {isConversationActive && <div className="absolute -bottom-0.5 -right-0.5 w-3 h-3 bg-green-500 border-2 border-white rounded-full animate-pulse"></div>}
//               </div>
//               <div className="min-w-0 text-left">
//                 <h3 className="font-bold text-slate-900 text-[15px] truncate leading-tight">{displayName}</h3>
//                 <p className={`text-[10px] font-bold uppercase ${isConversationActive ? 'text-green-500' : 'text-slate-400'}`}>
//                   {isConversationActive ? 'Đang hoạt động' : (isGroup ? `${convData.participants?.length} thành viên` : 'Ngoại tuyến')}
//                 </p>
//               </div>
//             </div>
//           </div>
//           <button onClick={() => setActiveOverlay('settings')} className="p-2 text-slate-500"><MoreVertical size={20} /></button>
//         </div>
//       </header>

//       {/* MESSAGES LIST */}
//       <main ref={scrollRef} onScroll={handleScroll} className="flex-1 overflow-y-auto p-4 bg-slate-50/30" style={{ backgroundImage: convData?.wallpaper ? `url(${convData.wallpaper})` : 'none', backgroundSize: 'cover' }}>
//         <div className="flex flex-col justify-end min-h-full">
//           {isFetchingMore && <div className="flex justify-center p-2"><Loader2 className="animate-spin text-blue-500 w-5 h-5" /></div>}

//           {messages.map((msg, idx) => {
//             const sender = msg.sender || {};
//             const isMe = (sender._id || sender) === (currentUser?.id || currentUser?._id);
//             const isShowFullTime = selectedFullTimeId === msg._id;
//             const parentMsg = msg.replyTo;

//             const isLastMessage = idx === messages.length - 1;

//             // Sửa dòng khai báo readers của bạn thành:
//             const readers = (msg.readBy || []).filter((u: any) => {
//               const uId = u._id || u;
//               const senderId = sender._id || sender;
//               const myId = currentUser?.id || currentUser?._id;
//               return uId !== senderId && uId !== myId;
//             });
//             // KIỂM TRA XEM CÓ PHẢI LÀ TIN NHẮN CHỈ CHỨA EMOJI KHÔNG
//             const bigEmoji = msg.text && isOnlyEmoji(msg.text);

//             // Gom nhóm các lượt reaction giống nhau để hiển thị (VD: 2 ❤️, 1 😂)
//             const groupedReactions = (msg.reactions || []).reduce((acc: any, curr: any) => {
//               acc[curr.emoji] = (acc[curr.emoji] || 0) + 1;
//               return acc;
//             }, {});
//             const reactionEntries = Object.entries(groupedReactions);

//             return (
//               <div key={msg._id || idx} className={`flex flex-col mb-4 animate-in fade-in duration-300`}>
//                 <div className={`group flex ${isMe ? 'justify-end' : 'justify-start'} items-end gap-2`}>

//                   {/* Avatar người gửi (nếu không phải mình) */}
//                   {!isMe && <img onClick={(e) => { e.stopPropagation(); goToProfile(sender._id || sender); }} src={sender.profilePicture ? `${API_BASE}/api/images/${sender.profilePicture}` : `https://ui-avatars.com/api/?name=${sender.fullName}`} className="w-7 h-7 rounded-full object-cover mb-1 border shadow-sm cursor-pointer hover:opacity-80 transition-opacity" alt="" title="Xem trang cá nhân" />}

//                   <div className={`flex flex-col max-w-[95%] ${isMe ? 'items-end' : 'items-start'}`}>
//                     {!isMe && <span className="text-[11px] font-bold text-slate-500 mb-1 ml-1">{sender.fullName}</span>}

//                     <div className={`flex items-center gap-2 w-full ${isMe ? 'flex-row-reverse' : 'flex-row'}`}>

//                       {/* CỤM NÚT HOVER: REPLY & REACT */}

//                       {/* CỤM NÚT HOVER: REPLY & REACT */}
//                       <div className={`opacity-0 group-hover:opacity-100 flex items-center gap-1 transition-all ${isMe ? 'flex-row-reverse' : 'flex-row'}`}>

//                         {/* Nút Trả lời */}
//                         <button onClick={() => setReplyingTo(msg)} className="p-1.5 text-slate-400 hover:text-slate-600 hover:bg-slate-200 rounded-full transition-all">
//                           <Reply size={15} />
//                         </button>

//                         {/* Nút Thùng rác - CHỈ HIỆN KHI LÀ TIN CỦA MÌNH */}
//                         {isMe && !msg.isRecalled && (
//                           <button
//                             onClick={() => handleDeleteMessage(msg._id)}
//                             className="p-1.5 text-slate-400 hover:text-red-600 hover:bg-red-50 rounded-full transition-all"
//                             title="Thu hồi tin nhắn"
//                           >
//                             <Trash2 size={15} />
//                           </button>
//                         )}

//                         {/* Nút Dịch */}
//                         {!isMe && msg.text && (
//                           <button
//                             onClick={() => handleTranslate(msg._id, msg.text)}
//                             className="p-1.5 text-slate-400 hover:text-blue-600 hover:bg-blue-50 rounded-full transition-all text-[10px] font-black"
//                           >
//                             {isTranslating[msg._id] ? <Loader2 size={15} className="animate-spin" /> : 'Dịch'}
//                           </button>
//                         )}

//                         {/* Nút thả cảm xúc (Wrapper dùng để bao bọc cả nút và khoảng hở) */}
//                         <div
//                           className="relative p-2 -m-2" // Thêm padding và margin âm để tạo vùng đệm (hover zone)
//                           onMouseEnter={() => setHoveredReactionMsgId(msg._id || idx.toString())}
//                           onMouseLeave={() => setTimeout(() => setHoveredReactionMsgId(null), 2000)}
//                         >
//                           {/* Nút mặt cười */}
//                           <button className="p-1.5 text-slate-400 hover:text-slate-600 hover:bg-slate-200 rounded-full transition-all">
//                             <Smile size={15} />
//                           </button>

//                           {/* BẢNG CHỌN EMOJI */}
//                           {hoveredReactionMsgId === (msg._id || idx.toString()) && (
//                             <div className={`absolute bottom-full mb-3 ${isMe ? 'right-0' : 'left-0'} bg-white shadow-xl border border-slate-100 rounded-2xl p-2 flex gap-2 flex-wrap w-[220px] z-[60] animate-in zoom-in-95 duration-200`}>
//                               {EMOJIS.map((emoji) => (
//                                 <button
//                                   key={emoji}
//                                   onClick={() => handleReactToMessage(msg._id, emoji)}
//                                   className="hover:scale-125 transition-transform text-xl w-7 h-7 flex items-center justify-center"
//                                 >
//                                   {emoji}
//                                 </button>
//                               ))}
//                             </div>
//                           )}
//                         </div>


//                       </div>
//                       {/* KHUNG TIN NHẮN (BONG BÓNG CHAT) */}

//                       <div className="relative w-fit max-w-[100%]">
//                         <div
//                           onClick={() => setSelectedFullTimeId(isShowFullTime ? null : (msg._id || idx.toString()))}
//                           onDoubleClick={() => {
//                             if (msg.text) {
//                               navigator.clipboard.writeText(msg.text).then(() => alert('Đã copy!')).catch(err => console.error(err));
//                             }
//                           }}
//                           className={`
//       cursor-pointer select-none transition-all active:scale-[0.98]
//       ${bigEmoji
//                               ? 'bg-transparent shadow-none border-none p-0 text-7xl md:text-8xl leading-none'
//                               : `px-4 py-3 rounded-[1.3rem] text-[15px] shadow-sm ${isMe ? 'text-white rounded-br-none' : 'bg-white text-slate-800 rounded-tl-[1.3rem] rounded-tr-[1.3rem] rounded-bl-none border border-slate-100'}`
//                             }
//     `}
//                           style={{
//                             backgroundColor: (isMe && !bigEmoji) ? activeTheme : undefined,
//                             wordBreak: 'break-word',
//                             overflowWrap: 'anywhere'
//                           }}
//                         >
//                           {/* Chỉ hiện Trích dẫn và Nội dung nếu KHÔNG PHẢI Big Emoji */}
//                           {!bigEmoji && (
//                             <>
//                               {parentMsg && (
//                                 <div className={`mb-2 p-2 rounded-lg border-l-4 text-[12px] line-clamp-2 ${isMe ? 'bg-black/15 border-white/60 text-white/90' : 'bg-slate-100 border-slate-300 text-slate-600'}`}>
//                                   <p className="font-black text-[12px]">{parentMsg.sender?.fullName || 'Người dùng'}</p>
//                                   <p className="italic opacity-80">{parentMsg.text || '[Hình ảnh]'}</p>
//                                 </div>
//                               )}

//                               <div className="flex flex-col min-w-[100px]">
//                                 <div className="text-[14px] leading-relaxed">
//                                   {renderContentWithLinks(msg.text, isMe)}
//                                 </div>
//                                 {translatedMessages[msg._id] && (
//                                   <div className="mt-2 pt-2 border-t border-black/10">
//                                     <p className="text-[13px] italic opacity-90 font-medium">
//                                       {renderContentWithLinks(translatedMessages[msg._id], isMe)}
//                                     </p>
//                                   </div>
//                                 )}
//                               </div>
//                             </>
//                           )}

//                           {/* Nếu là Big Emoji thì hiển thị nó */}
//                           {bigEmoji && <span>{msg.text}</span>}

//                           {/* Media (Ảnh/Video/File) */}
//                           {msg.media?.map((m: any, i: number) => {
//                             const publicUrl = m.url.startsWith('/var/www')
//                               ? `${API_BASE}/documents${m.url.replace('/var/www/deepcode-work-assets/documents', '')}`
//                               : (m.url.startsWith('http') ? m.url : `${API_BASE}${m.url}`);

//                             const fileName = m.url.split('/').pop();

//                             return m.type === 'file' ? (
//                               <div key={i} className="flex items-center gap-3 p-3 mt-2 bg-gray-50 rounded-xl border hover:bg-gray-100 transition-all cursor-pointer"
//                                 onClick={(e) => { e.stopPropagation(); const token = localStorage.getItem('token'); window.open(`${publicUrl}?token=${token}`, '_blank'); }}>
//                                 {getFileIcon(fileName)}
//                                 <div className="flex flex-col overflow-hidden">
//                                   <span className="text-sm font-semibold text-gray-800 truncate">{fileName}</span>
//                                   <span className="text-xs text-gray-500">{fileName.split('.').pop()?.toUpperCase()}</span>
//                                 </div>
//                               </div>
//                             ) : (
//                               <div key={i} className="mt-2 cursor-pointer overflow-hidden rounded-xl" onClick={() => setFullScreenMedia(m)}>
//                                 {m.type === 'video' ? (
//                                   <div className="relative group">
//                                     <video src={publicUrl} className="w-full max-h-[300px] object-cover" />
//                                     <div className="absolute inset-0 flex items-center justify-center bg-black/20 group-hover:bg-black/10"><Play size={32} color="white" /></div>
//                                   </div>
//                                 ) : (
//                                   <img src={publicUrl} className="w-full max-h-[300px] object-cover" alt="media" />
//                                 )}
//                               </div>
//                             );
//                           })}

//                           {/* {msg.survey && (
//                             <div className="mt-3 bg-white p-4 rounded-2xl border border-blue-100 shadow-sm w-full min-w-[250px]">
//                               <p className="font-bold text-sm mb-3 text-slate-800">{msg.survey.question}</p>
//                               <div className="space-y-2">
//                                 {msg.survey.options.map((opt: any, idx: number) => {
//                                   const totalVotes = msg.survey.options.reduce((sum: number, o: any) => sum + o.votes.length, 0);
//                                   const percent = totalVotes > 0 ? Math.round((opt.votes.length / totalVotes) * 100) : 0;
//                                   const isVoted = opt.votes.includes(currentUser?.id);

//                                   return (
//                                     <button
//                                       key={idx}
//                                       onClick={() => handleVote(msg._id, idx)}
//                                       className={`w-full text-left p-3 rounded-xl border relative overflow-hidden transition-all ${isVoted ? 'border-blue-400 bg-blue-50' : 'border-slate-100 bg-slate-50'}`}
//                                     >
//                                       <div className="absolute left-0 top-0 h-full bg-blue-100 transition-all duration-500" style={{ width: `${percent}%` }} />
//                                       <div className="relative z-10 flex justify-between items-center text-xs">
//                                         <span className="font-bold">{opt.text}</span>
//                                         <span className="font-black text-blue-600">{percent}%</span>
//                                       </div>
//                                     </button>
//                                   );
//                                 })}
//                               </div>
//                             </div>
//                           )} */}


//                           {msg.survey && (
//                             <div className="mt-3 bg-white p-4 rounded-2xl border border-blue-100 shadow-sm w-full max-w-[300px]">
//                               {/* Question */}
//                               <p className="font-bold text-sm mb-3 text-slate-800 break-words">
//                                 {msg.survey.question}
//                               </p>

//                               {/* Options */}



//                               <div className="space-y-2">
//                                 {msg.survey.options.map((opt: any, idx: number) => {
//                                   // 1. Tính toán lượt bình chọn
//                                   const totalVotes = msg.survey.options.reduce((sum: number, o: any) => sum + (o.votes?.length || 0), 0);
//                                   const percent = totalVotes > 0 ? Math.round(((opt.votes?.length || 0) / totalVotes) * 100) : 0;
//                                   const isVoted = opt.votes?.includes(currentUser?.id);

//                                   return (
//                                     <div key={idx} className="relative w-full">
//                                       <button
//                                         onClick={(e) => { e.stopPropagation(); handleVote(msg._id, idx); }}
//                                         className={`w-full text-left p-3 rounded-xl border relative overflow-hidden transition-all duration-300 ${isVoted ? 'border-blue-500 bg-blue-50' : 'border-slate-100 bg-slate-50 hover:border-blue-200'
//                                           }`}
//                                       >
//                                         {/* Thanh tiến trình */}
//                                         <div
//                                           className="absolute left-0 top-0 h-full bg-blue-100 transition-all duration-500 ease-out"
//                                           style={{ width: `${percent}%` }}
//                                         />

//                                         {/* Nội dung đáp án */}
//                                         <div className="relative z-10 flex justify-between items-center text-xs">
//                                           <span className={`font-bold truncate pr-2 ${isVoted ? 'text-blue-900' : 'text-slate-700'}`}>
//                                             {opt.text}
//                                           </span>

//                                           {/* Click vào số lượt vote để hiện popup danh sách người đã bình chọn */}
//                                           <span
//                                             className="font-black text-blue-600 hover:text-blue-800 underline decoration-blue-300 shrink-0 cursor-pointer"
//                                             onClick={(e) => {
//                                               e.stopPropagation();
//                                               // Truyền danh sách người đã vote vào popup
//                                               setUserListPopup({
//                                                 isOpen: true,
//                                                 users: opt.votes || [], // Danh sách người đã vote
//                                                 title: `Người chọn: ${opt.text}`
//                                               });
//                                             }}
//                                           >
//                                             {opt.votes?.length || 0} lượt ({percent}%)
//                                           </span>
//                                         </div>
//                                       </button>
//                                     </div>
//                                   );
//                                 })}
//                               </div>

//                               {/* Hiển thị tổng lượt bình chọn */}
//                               <p className="text-[10px] text-slate-400 mt-2 font-bold uppercase">
//                                 {msg.survey.options.reduce((sum: number, o: any) => sum + (o.votes?.length || 0), 0)} lượt bình chọn
//                               </p>
//                             </div>
//                           )}


//                         </div>

//                         {/* REACTIONS (Chỉ hiện nếu không phải Big Emoji để tránh che mất mặt Emoji) */}
//                         {/* {!bigEmoji && reactionEntries.length > 0 && (
//                           <div className={`absolute -bottom-4 ${isMe ? 'left-2' : 'right-2'} bg-white border border-slate-100 shadow-lg rounded-full px-2 py-1 flex items-center gap-1.5 z-10 select-none cursor-pointer hover:scale-110 transition-transform`}>
//                             {reactionEntries.map(([emoji, count]) => (
//                               <span key={emoji} className="flex items-center gap-0.5">
//                                 <span className="text-xl leading-none">{emoji}</span>
//                                 {Number(count) > 1 && <span className="font-black text-slate-700 text-[11px] ml-0.5">{String(count)}</span>}
//                               </span>
//                             ))}
//                           </div>
//                         )} */}


//                         {!bigEmoji && reactionEntries.length > 0 && (
//                           <div
//                             onClick={() => setUserListPopup({
//                               isOpen: true,
//                               users: msg.reactions.map((r: any) => r.user), // Truyền danh sách user đã react
//                               title: 'Đã bày tỏ cảm xúc'
//                             })}
//                             className={`absolute -bottom-4 ${isMe ? 'left-2' : 'right-2'} bg-white border border-slate-100 shadow-lg rounded-full px-2 py-1 flex items-center gap-1.5 z-10 select-none cursor-pointer hover:scale-110 transition-transform`}
//                           >
//                             {reactionEntries.map(([emoji, count]) => (
//                               <span key={emoji} className="flex items-center gap-0.5">
//                                 <span className="text-xl leading-none">{emoji}</span>
//                                 {Number(count) > 0 && <span className="font-black text-slate-700 text-[11px] ml-0.5">{String(count)}</span>}
//                               </span>
//                             ))}
//                           </div>
//                         )}
//                       </div>
//                     </div>
//                     <span className={`text-[8px] font-bold mt-1 uppercase px-1 transition-all ${isShowFullTime ? 'text-blue-500 scale-105' : 'text-slate-400'}`}>
//                       {isShowFullTime ? formatFullDate(msg.createdAt) : new Date(msg.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
//                     </span>
//                     {/* HIỂN THỊ ĐÃ XEM */}

//                     {isLastMessage && readers.length > 0 && (
//                       <div
//                         onClick={() => setUserListPopup({
//                           isOpen: true,
//                           users: readers,
//                           title: 'Đã xem'
//                         })}
//                         className={`flex items-center gap-1 mt-1 cursor-pointer hover:opacity-80 transition-opacity ${isMe ? 'justify-end' : 'justify-start'}`}
//                       >
//                         {/* ... code hiển thị avatar readers ... */}

//                         <div className="flex -space-x-1.5">
//                           {readers.slice(0, 3).map((r: any, ri: number) => (
//                             <img
//                               key={r._id || ri}
//                               src={r.profilePicture ? `${API_BASE}/api/images/${r.profilePicture}` : `https://ui-avatars.com/api/?name=${r.fullName}`}
//                               className="w-3.5 h-3.5 rounded-full border-2 border-white object-cover shadow-sm"
//                               title={r.fullName}
//                               alt=""
//                             />
//                           ))}
//                         </div>
//                         <span className="text-[9px] text-slate-400 font-bold ml-1">
//                           {readers.length > 3 ? `+${readers.length - 3}` : `Đã xem`}
//                         </span>
//                       </div>
//                     )}




//                   </div>
//                 </div>
//               </div>
//             );
//           })}
//           {isRemoteTyping && <div className="text-[10px] text-slate-400 italic mt-2 ml-10 animate-pulse">Ai đó đang nhập...</div>}
//         </div>
//       </main>
//       {/* FOOTER */}
//       <footer className="flex-shrink-0 bg-white border-t border-slate-100 relative pb-[env(safe-area-inset-bottom)]">
//         {/* Thanh trạng thái Replying */}
//         {replyingTo && (
//           <div className="absolute bottom-full left-0 w-full bg-slate-50/95 backdrop-blur-sm border-t border-slate-200 p-2 flex items-center justify-between animate-in slide-in-from-bottom-2 duration-200">
//             <div className="flex items-center gap-2 border-l-4 border-blue-500 pl-3 overflow-hidden">
//               <div className="flex flex-col min-w-0">
//                 <span className="text-[10px] font-black text-blue-600 uppercase tracking-tight">Đang phản hồi {replyingTo.sender?.fullName}</span>
//                 <span className="text-[12px] text-slate-500 truncate italic">{replyingTo.text || "[Hình ảnh]"}</span>
//               </div>
//             </div>
//             <button
//               onClick={() => setReplyingTo(null)}
//               className="p-1.5 bg-slate-200 text-slate-600 rounded-full flex-shrink-0 ml-2"
//             >
//               <X size={14} strokeWidth={3} />
//             </button>
//           </div>
//         )}
//         {/* Khung nhập liệu chính - Tối ưu Gap để không bị tràn */}
//         {/* Bọc toàn bộ trong <form> và dùng onSubmit thay cho onKeyDown ở input */}
//         <form
//           className="flex items-center gap-0.5 p-1.5 md:p-3 w-full"
//           onSubmit={(e) => {
//             e.preventDefault(); // Chặn reload trang
//             if (inputValue.trim()) {
//               handleSend({});
//             }
//           }}
//         >
//           {/* Nhóm nút chức năng bên trái: Emoji, Sticker, Image (giữ nguyên) */}
//           <div className="flex items-center flex-shrink-0">
//             <button type="button" onClick={() => setActiveOverlay('emoji')} className="p-1.5 md:p-2 text-slate-500 active:scale-75 transition-transform">
//               <Smile size={22} />
//             </button>
//             <button type="button" onClick={() => setActiveOverlay('stickers')} className="p-1.5 md:p-2 text-slate-500 active:scale-75 transition-transform">
//               <StickyNote size={22} />
//             </button>
//             {/* Nút gửi ảnh */}
//             <button
//               type="button"

//               onClick={() => {
//                 const input = document.createElement('input');
//                 input.type = 'file';
//                 input.accept = 'image/*';
//                 input.onchange = async (e: any) => {
//                   const file = e.target.files?.[0];
//                   if (!file) return;
//                   const formData = new FormData();
//                   formData.append('image', file);
//                   const res = await apiFetch('/api/images/upload', {
//                     method: 'POST',
//                     headers: { 'Authorization': `Bearer ${localStorage.getItem('token')}` },
//                     body: formData
//                   });
//                   const data = await res.json();
//                   if (res.ok) handleSend({ image: `${API_BASE}/api/images/${data.image._id}` });
//                 };
//                 input.click();
//               }}
//               className="p-1.5 md:p-2 text-slate-500 active:scale-75 transition-transform"
//               title="Gửi ảnh"
//             >
//               <ImageIcon size={22} />
//             </button>

//             {/* Nút Upload Tài liệu */}
//             <button
//               type="button"
//               onClick={() => {
//                 // Tạo input ẩn để chọn file
//                 const input = document.createElement('input');
//                 input.type = 'file';
//                 // Đặt accept cho các loại file tài liệu
//                 input.accept = '.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.tsx,.js,.jsx,.java,.ts,.zip,.rar';

//                 input.onchange = async (e: any) => {
//                   const file = e.target.files?.[0];
//                   if (file) {
//                     // GỌI HÀM Ở ĐÂY
//                     await handleUploadDocument(file);
//                   }
//                 };
//                 input.click();
//               }}
//               className="p-1.5 md:p-2 text-slate-500 active:scale-75 transition-transform"
//               title="Gửi tài liệu"
//             >
//               <FileUp size={22} />
//             </button>

//             <button
//               type="button"
//               onClick={() => setActiveOverlay('survey')}
//               className="p-1.5 md:p-2 text-slate-500 active:scale-75 transition-transform"
//               title="Tạo khảo sát"
//             >
//               <ListChecks size={22} />
//             </button>
//           </div>
//           {/* Input field */}
//           {/* Thay Input bằng Textarea */}
//           <div className="flex-1 bg-slate-100 rounded-2xl px-3 md:px-4 flex items-center min-h-[40px] max-h-[120px] overflow-y-auto mx-1">
//             <textarea
//               rows={1}
//               placeholder="Tin nhắn..."
//               value={inputValue}
//               onChange={(e) => {
//                 setInputValue(e.target.value);
//                 // Tự động điều chỉnh độ cao nếu cần (tùy chọn)
//                 e.target.style.height = 'auto';
//                 e.target.style.height = e.target.scrollHeight + 'px';

//                 socketRef.current?.emit('typing', { conversationId: convId, isTyping: e.target.value.length > 0 });
//               }}
//               onPaste={handlePaste} // <--- Thêm sự kiện này

//               onKeyDown={(e) => {
//                 if (e.key === 'Enter' && !e.shiftKey) {
//                   e.preventDefault();
//                   handleSend({});
//                 }
//               }}
//               className="flex-1 bg-transparent border-none text-[15px] py-3 outline-none w-full resize-none leading-relaxed"
//             />
//           </div>
//           {/* Nút gửi - Đổi type="submit" để form tự bắt sự kiện nhấn Enter */}
//           <div className="flex-shrink-0 flex items-center justify-center pr-1">
//             <button
//               type="submit"
//               disabled={!inputValue.trim()}
//               className={`p-2 md:p-2.5 rounded-full transition-all flex items-center justify-center ${inputValue.trim()
//                 ? 'bg-blue-600 text-white shadow-md active:scale-90'
//                 : 'text-slate-300'
//                 }`}
//             >
//               <Send size={18} fill={inputValue.trim() ? "currentColor" : "none"} />
//             </button>
//           </div>
//         </form>
//       </footer>
//       {/* OVERLAY SETTINGS */}
//       {/* OVERLAY SETTINGS */}
//       {activeOverlay === 'settings' && (
//         <div className="fixed inset-0 bg-white z-[200] flex flex-col pt-[env(safe-area-inset-top)] animate-in slide-in-from-bottom duration-300">
//           <div className="h-14 px-4 border-b border-slate-100 flex items-center justify-between shrink-0">
//             <h4 className="font-black text-slate-800 uppercase tracking-widest text-xs">Cài đặt hội thoại</h4>
//             <button onClick={() => { setActiveOverlay('none'); setIsEditingName(false); }} className="p-2 bg-slate-50 rounded-full"><X size={20} /></button>
//           </div>
//           <div className="flex-1 overflow-y-auto p-6 space-y-10 custom-scrollbar">
//             <div className="text-center space-y-4">
//               {/* SỬA LẠI ĐOẠN ẢNH VÀ TÊN NÀY TRONG SETTINGS */}
//               <div className="relative inline-block group">
//                 <img
//                   src={
//                     isGroup
//                       ? (convData?.groupAvatar ? `${API_BASE}/api/images/${convData.groupAvatar}` : `https://ui-avatars.com/api/?name=${displayName || 'Group'}`)
//                       : (otherMember?.profilePicture ? `${API_BASE}/api/images/${otherMember.profilePicture}` : `https://ui-avatars.com/api/?name=${displayName || 'User'}`)
//                   }
//                   className="w-28 h-28 rounded-[2rem] mx-auto shadow-2xl border-4 border-white object-cover"
//                   alt="Avatar"
//                 />
//                 {isGroup && isCreator && (
//                   <button
//                     onClick={() => groupAvatarInputRef.current?.click()}
//                     className="absolute bottom-0 right-0 p-2 bg-blue-600 text-white rounded-xl shadow-lg border-2 border-white active:scale-90"
//                   >
//                     <Camera size={18} />
//                   </button>
//                 )}
//               </div>
//               <div className="flex flex-col items-center">
//                 {isEditingName ? (
//                   <div className="flex items-center gap-2 w-full max-w-xs"><input autoFocus className="flex-1 text-center font-black text-xl border-b-2 border-blue-600 outline-none" value={tempName} onChange={(e) => setTempName(e.target.value)} /><button onClick={() => { updateGroupInfo({ name: tempName }); setIsEditingName(false); }} className="p-2 bg-green-500 text-white rounded-lg shadow-md"><Check size={16} /></button></div>
//                 ) : (
//                   <div className="flex items-center gap-2"><h2 className="text-2xl font-black text-slate-900">{displayName}</h2>{isGroup && isCreator && <Edit2 size={16} className="text-slate-400 cursor-pointer" onClick={() => setIsEditingName(true)} />}</div>
//                 )}
//               </div>
//             </div>
//             <div className="space-y-4">
//               <p className="text-[10px] font-black text-slate-400 uppercase tracking-[0.2em] text-center">Chủ đề hội thoại</p>
//               <div className="flex flex-wrap justify-center gap-4">{THEMES.map(color => <button key={color} onClick={() => updateGroupInfo({ themeColor: color })} className="w-10 h-10 rounded-full border-4 border-white shadow-md flex items-center justify-center transition-transform active:scale-90" style={{ backgroundColor: color }}>{activeTheme === color && <Check size={20} className="text-white" strokeWidth={4} />}</button>)}</div>
//             </div>

//             <div className="space-y-4">
//               {/* HEADER */}
//               <div className="flex items-center justify-between">
//                 <p
//                   onClick={() => setIsOpenMembers(prev => !prev)}
//                   className="text-[10px] font-black text-slate-400 uppercase tracking-[0.2em] cursor-pointer"
//                 >
//                   Thành viên ({convData?.participants?.length})
//                 </p>

//                 <div className="flex items-center gap-2">
//                   {isGroup && isCreator && (
//                     <button
//                       onClick={fetchUsersToAdd}
//                       className="flex items-center gap-1 text-[10px] font-black text-blue-600 uppercase bg-blue-50 px-3 py-1.5 rounded-xl active:scale-95"
//                     >
//                       <UserPlus size={12} /> Thêm người
//                     </button>
//                   )}

//                   <button
//                     onClick={() => setIsOpenMembers(prev => !prev)}
//                     className="p-2 hover:bg-slate-100 rounded-xl transition"
//                   >
//                     {isOpenMembers ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
//                   </button>
//                 </div>
//               </div>

//               {/* LIST */}
//               <div
//                 className={`bg-slate-50 rounded-3xl p-2 space-y-1 overflow-hidden transition-all duration-300 ${isOpenMembers ? 'max-h-[500px] opacity-100' : 'max-h-0 opacity-0'
//                   }`}
//               >
//                 {convData?.participants?.map((p: any) => {
//                   const pId = p._id?.toString() || p.id?.toString();
//                   const creatorId = (convData.createdBy?._id || convData.createdBy)?.toString();

//                   return (
//                     <div
//                       key={pId}
//                       className="flex items-center justify-between p-3 hover:bg-white rounded-2xl transition-all group/member"
//                     >
//                       <div className="flex items-center gap-3">
//                         <img
//                           src={
//                             p.profilePicture
//                               ? `${API_BASE}/api/images/${p.profilePicture}`
//                               : `https://ui-avatars.com/api/?name=${p.fullName}`
//                           }
//                           className="w-9 h-9 rounded-full object-cover border shadow-sm"
//                           alt=""
//                         />
//                         <div className="min-w-0">
//                           <p className="text-sm font-bold text-slate-700 truncate">
//                             {p.fullName}
//                           </p>
//                           <p className="text-[9px] text-slate-400 font-medium uppercase">
//                             {p.department || 'Nhân sự'}
//                           </p>
//                         </div>
//                       </div>

//                       <div className="flex items-center gap-2">
//                         {pId === creatorId ? (
//                           <span className="text-[8px] bg-blue-100 text-blue-600 px-2 py-0.5 rounded-full font-black uppercase">
//                             Chủ nhóm
//                           </span>
//                         ) : (
//                           isCreator && (
//                             <button
//                               onClick={() => handleRemoveMember(pId)}
//                               className="p-2 text-red-400 hover:text-red-600 hover:bg-red-50 rounded-xl transition-all"
//                             >
//                               <X size={16} />
//                             </button>
//                           )
//                         )}
//                       </div>
//                     </div>
//                   );
//                 })}
//               </div>
//             </div>


//             <div className="space-y-4 pt-6 border-t border-slate-100">
//               {/* HEADER */}
//               <div className="flex items-center justify-between group cursor-pointer" onClick={() => setIsOpenFiles(!isOpenFiles)}>
//                 <p className="text-[10px] font-black text-slate-400 uppercase tracking-[0.2em] group-hover:text-blue-600 transition-colors">
//                   Danh sách tệp ({chatFiles?.length || 0})
//                 </p>
//                 <button className="p-2 hover:bg-slate-100 rounded-xl transition-all text-slate-400">
//                   {isOpenFiles ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
//                 </button>
//               </div>

//               {/* GRID FILE - HIỆU ỨNG TRƯỢT */}
//               <div className={`overflow-hidden transition-all duration-500 ease-in-out ${isOpenFiles ? 'max-h-[600px] opacity-100' : 'max-h-0 opacity-0'}`}>
//                 <div className="space-y-3 p-1">

//                   {/* Bộ lọc và Tìm kiếm */}
//                   <div className="flex gap-2 mb-2">
//                     <div className="relative flex-1">
//                       <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={14} />
//                       <input
//                         type="text" placeholder="Tìm tên file..."
//                         className="w-full pl-9 pr-3 py-2 bg-slate-50 border border-slate-100 rounded-xl text-[10px] font-bold outline-none focus:ring-1 focus:ring-blue-500"
//                         onChange={(e) => setFileSearch(e.target.value)}
//                       />
//                     </div>
//                   </div>


//                   <div className="grid grid-cols-2 gap-3">
//                     {chatFiles && chatFiles.length > 0 ? (
//                       <>
//                         {chatFiles
//                           // 1. Dùng fileSearch thay cho searchUser để tránh xung đột
//                           .filter(f => f.name.toLowerCase().includes(fileSearch.toLowerCase()))
//                           .map((file: any) => {
//                             const isImage = file.mimeType?.includes('image');

//                             // 2. Xử lý đường dẫn file: Cắt bỏ path server, lấy phần route tĩnh
//                             // Giả sử API static của bạn là '/documents'
//                             const relativePath = file.fileUrl.replace('/var/www/deepcode-work-assets/documents', '');
//                             const fileUrl = file.fileUrl?.startsWith('http') ? file.fileUrl : `${API_BASE}/documents${relativePath}`;

//                             return (
//                               <div
//                                 key={file._id}
//                                 className="bg-white rounded-2xl p-3 shadow-sm border border-slate-100 hover:border-blue-200 transition-all group cursor-pointer flex flex-col items-center"
//                                 // 3. FIX LỖI: Truyền file vào hàm handleDownload
//                                 onClick={() => handleDownload(file)}
//                               >
//                                 <div className="flex justify-center items-center h-12 w-12 mb-2 overflow-hidden rounded-lg bg-slate-50">
//                                   {isImage ? (
//                                     <img src={fileUrl} className="h-full w-full object-cover" alt={file.name} onError={(e) => e.currentTarget.style.display = 'none'} />
//                                   ) : (
//                                     <FileText size={24} className="text-blue-500" />
//                                   )}
//                                 </div>
//                                 <p className="text-[10px] font-bold text-slate-800 truncate w-full text-center">{file.name}</p>
//                                 <p className="text-[9px] text-slate-400 text-center">{formatSize(file.size)}</p>
//                               </div>
//                             );
//                           })}

//                         {/* Nút Xem thêm */}
//                         {hasMoreFiles && (
//                           <button
//                             onClick={() => { setFilesPage(p => p + 1); fetchChatFiles(filesPage + 1); }}
//                             className="col-span-2 py-2 text-[10px] font-black text-blue-600 hover:underline uppercase"
//                           >
//                             Xem thêm
//                           </button>
//                         )}
//                       </>
//                     ) : (
//                       <p className="col-span-2 text-center text-[10px] text-slate-400 py-4 italic">
//                         Chưa có tài liệu nào
//                       </p>
//                     )}
//                   </div>


//                 </div>
//               </div>
//             </div>

//             <div className="pt-6 border-t border-slate-100 space-y-3">
//               {isGroup && <><button onClick={handleLeaveGroup} className="w-full py-4 bg-orange-50 text-orange-600 rounded-2xl font-black text-xs uppercase tracking-widest flex items-center justify-center gap-2 active:bg-orange-100 transition-all"><LogOut size={16} /> Rời khỏi nhóm</button>{isCreator && <button onClick={handleDeleteGroup} className="w-full py-4 bg-red-50 text-red-600 rounded-2xl font-black text-xs uppercase tracking-widest flex items-center justify-center gap-2 active:bg-red-100 transition-all"><Trash2 size={16} /> Giải tán nhóm (Xoá vĩnh viễn)</button>}</>}
//             </div>
//           </div>
//           {isAddingMember && (
//             <div className="absolute inset-0 bg-white z-[210] flex flex-col animate-in slide-in-from-right duration-300">
//               <div className="h-14 px-4 border-b flex items-center justify-between shrink-0"><button onClick={() => setIsAddingMember(false)} className="p-2 bg-slate-50 rounded-full"><ChevronLeft size={20} /></button><h4 className="font-black text-xs uppercase tracking-widest">Thêm thành viên</h4><div className="w-10"></div></div>
//               <div className="p-4 border-b"><div className="relative"><Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={16} /><input type="text" placeholder="Tìm đồng nghiệp..." className="w-full pl-10 pr-4 py-2.5 bg-slate-100 border-none rounded-xl text-sm focus:ring-2 focus:ring-blue-500" value={searchUser} onChange={(e) => setSearchUser(e.target.value)} /></div></div>
//               <div className="flex-1 overflow-y-auto p-4 space-y-2 custom-scrollbar">
//                 {allUsers.filter(u => u.fullName.toLowerCase().includes(searchUser.toLowerCase())).map(u => (
//                   <button key={u._id} onClick={() => handleAddMembers([u._id])} className="w-full flex items-center gap-4 p-3 hover:bg-slate-50 rounded-2xl transition-all text-left group"><img src={u.profilePicture ? `${API_BASE}/api/images/${u.profilePicture}` : `https://ui-avatars.com/api/?name=${u.fullName}`} className="w-11 h-11 rounded-xl object-cover shadow-sm" alt="" /><div className="flex-1 min-w-0"><p className="text-sm font-black text-slate-900 truncate">{u.fullName}</p><p className="text-[10px] text-slate-400 uppercase font-bold">{u.department}</p></div><div className="p-2 bg-blue-50 text-blue-600 rounded-lg group-hover:bg-blue-600 group-hover:text-white transition-all"><Plus size={16} /></div></button>
//                 ))}
//                 {allUsers.length === 0 && <p className="text-center text-xs text-slate-400 py-10">Mọi người đều đã ở trong nhóm</p>}
//               </div>
//             </div>
//           )}
//           {isUpdating && <div className="absolute inset-0 bg-white/60 backdrop-blur-[2px] flex items-center justify-center z-[250]"><Loader2 className="animate-spin text-blue-600 w-10 h-10" /></div>}
//         </div>
//       )}

//       {/* STICKER OVERLAY - CẢI TIẾN HIỂN THỊ */}
//       {activeOverlay === 'stickers' && (
//         <div className="fixed inset-0 bg-white z-[200] flex flex-col pt-[env(safe-area-inset-top)] animate-in slide-in-from-bottom duration-300">
//           <div className="h-14 px-4 border-b border-slate-100 flex items-center justify-between shrink-0">
//             <h4 className="font-black text-slate-800 uppercase tracking-widest text-xs">Stickers & GIF</h4>
//             <button onClick={() => setActiveOverlay('none')} className="p-2 bg-slate-50 rounded-full hover:bg-slate-100 transition-all"><X size={20} /></button>
//           </div>

//           <div className="flex-1 overflow-y-auto p-4 custom-scrollbar">
//             <div className="grid grid-cols-3 gap-3">
//               {STICKERS.map((s, i) => (
//                 <button
//                   key={i}
//                   onClick={() => { handleSend({ image: s }); setActiveOverlay('none'); }}
//                   className="relative aspect-square rounded-2xl overflow-hidden bg-slate-50 hover:bg-blue-50 border border-slate-100 transition-all active:scale-90 flex items-center justify-center p-2 shadow-sm"
//                 >
//                   <img src={s} className="w-full h-full object-contain" alt={`sticker-${i}`} loading="lazy" />
//                 </button>
//               ))}
//             </div>
//             {/* Khoảng đệm cuối danh sách để không bị che bởi thanh điều hướng hệ thống */}
//             <div className="h-10"></div>
//           </div>
//         </div>
//       )}


//       {/* EMOJI OVERLAY - FIX: ICON TO, KHÔNG BORDER */}
//       {activeOverlay === 'emoji' && (
//         <div className="fixed inset-0 bg-white z-[200] flex flex-col pt-[env(safe-area-inset-top)] animate-in slide-in-from-bottom duration-300">
//           {/* Header của Overlay */}
//           <div className="h-14 px-4 border-b border-slate-100 flex items-center justify-between shrink-0">
//             <h4 className="font-black text-slate-800 uppercase tracking-widest text-xs">Biểu cảm</h4>
//             <button
//               onClick={() => setActiveOverlay('none')}
//               className="p-2 bg-slate-50 rounded-full hover:bg-slate-100 transition-colors"
//             >
//               <X size={20} />
//             </button>
//           </div>

//           {/* Vùng hiển thị Emoji */}
//           <div className="flex-1 overflow-y-auto p-4 custom-scrollbar">
//             <div className="grid grid-cols-5 gap-y-6 gap-x-2 justify-items-center">
//               {EMOJIS.map((e, i) => (
//                 <button
//                   key={i}
//                   onClick={() => { setInputValue(v => v + e); setActiveOverlay('none'); }}
//                   className="text-5xl p-2 bg-transparent border-none outline-none transition-all active:scale-150 hover:scale-125 flex items-center justify-center"
//                 >
//                   {e}
//                 </button>
//               ))}
//             </div>
//             {/* Khoảng đệm cuối */}
//             <div className="h-10"></div>
//           </div>
//         </div>
//       )}

//       {/* POPUP DANH SÁCH USER (DÙNG CHUNG CHO CẢ ĐÃ XEM & ĐÃ REACT) */}
//       {userListPopup.isOpen && (
//         <div className="fixed inset-0 z-[300] bg-black/50 backdrop-blur-sm flex items-center justify-center p-4">
//           <div className="bg-white w-full max-w-sm rounded-3xl p-4 shadow-2xl animate-in zoom-in-95 duration-200">
//             <div className="flex justify-between items-center mb-4">
//               <h3 className="font-black text-sm uppercase text-slate-700">{userListPopup.title} ({userListPopup.users.length})</h3>
//               <button onClick={() => setUserListPopup({ isOpen: false, users: [], title: '' })} className="p-1 rounded-full hover:bg-slate-100">
//                 <X size={20} />
//               </button>
//             </div>

//             <div className="max-h-[300px] overflow-y-auto custom-scrollbar space-y-2">
//               {userListPopup.users.map((u: any) => (
//                 <div
//                   key={u._id}
//                   onClick={() => goToProfile(u._id)}
//                   className="flex items-center gap-3 p-2 hover:bg-slate-50 rounded-xl cursor-pointer transition-all"
//                 >
//                   <img
//                     src={u.profilePicture ? `${API_BASE}/api/images/${u.profilePicture}` : `https://ui-avatars.com/api/?name=${u.fullName}`}
//                     className="w-10 h-10 rounded-full object-cover border"
//                     alt={u.fullName}
//                   />
//                   <span className="font-bold text-sm text-slate-800">{u.fullName}</span>
//                 </div>
//               ))}
//             </div>
//           </div>
//         </div>
//       )}

//       {activeOverlay === 'survey' && (
//         <div className="fixed inset-0 z-[200] bg-white flex flex-col pt-[env(safe-area-inset-top)] animate-in slide-in-from-bottom duration-300">
//           {/* Header */}
//           <div className="h-14 px-4 border-b border-slate-100 flex items-center justify-between shrink-0">
//             <h4 className="font-black text-slate-800 uppercase tracking-widest text-xs">Tạo khảo sát</h4>
//             <button onClick={() => setActiveOverlay('none')} className="p-2 bg-slate-50 rounded-full hover:bg-slate-100 transition-all"><X size={20} /></button>
//           </div>

//           {/* Content */}
//           <div className="flex-1 overflow-y-auto p-6 space-y-6 custom-scrollbar">
//             {/* Câu hỏi */}
//             <div className="space-y-2">
//               <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Câu hỏi khảo sát</label>
//               <input
//                 placeholder="Bạn muốn hỏi gì?"
//                 value={surveyQuestion}
//                 onChange={(e) => setSurveyQuestion(e.target.value)}
//                 className="w-full px-5 py-4 bg-slate-50 rounded-2xl border-none font-bold text-sm focus:ring-2 focus:ring-blue-500 outline-none"
//               />
//             </div>

//             {/* Danh sách lựa chọn */}
//             <div className="space-y-3">
//               <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Các lựa chọn</label>
//               {surveyOptions.map((opt, idx) => (
//                 <div key={idx} className="flex gap-2">
//                   <input
//                     placeholder={`Lựa chọn ${idx + 1}`}
//                     value={opt}
//                     onChange={(e) => {
//                       const newOptions = [...surveyOptions];
//                       newOptions[idx] = e.target.value;
//                       setSurveyOptions(newOptions);
//                     }}
//                     className="flex-1 px-5 py-3 bg-slate-50 rounded-2xl border-none font-bold text-sm focus:ring-2 focus:ring-blue-500 outline-none"
//                   />
//                   {surveyOptions.length > 2 && (
//                     <button onClick={() => setSurveyOptions(prev => prev.filter((_, i) => i !== idx))} className="text-red-400 p-2"><X size={18} /></button>
//                   )}
//                 </div>
//               ))}

//               <button
//                 onClick={() => setSurveyOptions([...surveyOptions, ''])}
//                 className="w-full py-3 border-2 border-dashed border-slate-200 rounded-2xl text-[10px] font-black text-slate-400 uppercase hover:border-blue-400 hover:text-blue-600 transition-all"
//               >
//                 + Thêm lựa chọn
//               </button>
//             </div>
//           </div>

//           {/* Footer */}
//           <div className="p-6 border-t border-slate-100">
//             {/* <button
//               disabled={!surveyQuestion.trim() || surveyOptions.some(o => !o.trim())}
//               onClick={() => {
//                 handleSend({
//                   text: `📊 Khảo sát: ${surveyQuestion}`,
//                   // Gửi dữ liệu survey vào tin nhắn để Backend lưu vào DB
//                 });
//                 // Lưu ý: Trong hàm handleSend, bạn cần thêm logic xử lý object 'survey' 
//                 // nếu muốn lưu survey vào database thay vì chỉ gửi dạng text
//                 setActiveOverlay('none');
//                 setSurveyQuestion('');
//                 setSurveyOptions(['', '']);
//               }}
//               className="w-full py-4 bg-blue-600 text-white rounded-2xl font-black uppercase text-sm hover:bg-blue-700 disabled:opacity-50 transition-all active:scale-95"
//             >
//               Gửi khảo sát
//             </button> */}


//             <button
//               disabled={!surveyQuestion.trim() || surveyOptions.some(o => !o.trim())}
//               onClick={() => {
//                 // Gọi handleSend với đầy đủ object survey
//                 // handleSend({
//                 //   text: `📊 ${surveyQuestion}`, // Nội dung text hiển thị trước
//                 //   survey: {
//                 //     question: surveyQuestion,
//                 //     options: surveyOptions.map(opt => ({ text: opt, votes: [] })), // Khởi tạo mảng votes rỗng
//                 //     multipleChoice: false,
//                 //     closed: false
//                 //   }
//                 // });

//                 handleSend({
//                   text: `📊 ${surveyQuestion}`,
//                   survey: {
//                     question: surveyQuestion,
//                     options: surveyOptions.map(opt => ({ text: opt, votes: [] })),
//                     multipleChoice: false,
//                     closed: false
//                   }
//                 });
//                 // Reset form
//                 setSurveyQuestion('');
//                 setSurveyOptions(['', '']);
//               }}
//               className="w-full py-4 bg-blue-600 text-white rounded-2xl font-black uppercase text-sm hover:bg-blue-700 disabled:opacity-50 transition-all active:scale-95"
//             >
//               Gửi khảo sát
//             </button>
//           </div>
//         </div>
//       )}


//       {fullScreenMedia && (
//         <div
//           className="fixed inset-0 z-[500] bg-black/95 flex items-center justify-center animate-in fade-in duration-200"
//           onClick={() => setFullScreenMedia(null)} // Click vào nền đen là tắt
//         >
//           {/* Nút tắt góc phải - Thêm stopPropagation để click vào nút không bị đóng nhầm */}
//           <button
//             className="absolute top-6 right-6 p-2 bg-white/10 hover:bg-white/20 rounded-full text-white backdrop-blur-md transition-all z-[501]"
//             onClick={(e) => {
//               e.stopPropagation();
//               setFullScreenMedia(null);
//             }}
//           >
//             <X size={32} />
//           </button>

//           {/* Nút tải xuống (Tuỳ chọn: bổ sung để chuyên nghiệp) */}
//           <a
//             href={fullScreenMedia.url.startsWith('http') ? fullScreenMedia.url : `${API_BASE}${fullScreenMedia.url}`}
//             download
//             onClick={(e) => e.stopPropagation()}
//             className="absolute top-6 right-20 p-2 bg-white/10 hover:bg-white/20 rounded-full text-white backdrop-blur-md transition-all z-[501]"
//           >
//             <Download size={32} />
//           </a>

//           {/* Content */}
//           <div
//             className="w-full h-full flex items-center justify-center p-4"
//             onClick={(e) => e.stopPropagation()} // Click vào ảnh không làm đóng popup
//           >
//             {fullScreenMedia.type === 'video' ? (
//               <video
//                 src={fullScreenMedia.url.startsWith('http') ? fullScreenMedia.url : `${API_BASE}${fullScreenMedia.url}`}
//                 controls
//                 autoPlay
//                 className="max-w-full max-h-[90vh] rounded-xl shadow-2xl"
//               />
//             ) : (
//               <img
//                 src={fullScreenMedia.url.startsWith('http') ? fullScreenMedia.url : `${API_BASE}${fullScreenMedia.url}`}
//                 className="max-w-full max-h-[90vh] object-contain rounded-xl shadow-2xl"
//                 alt="full"
//               />
//             )}
//           </div>
//         </div>
//       )}
//     </div>
//   );
// };

// export default MobileChatRoom;